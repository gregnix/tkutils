# kb-store.tcl -- data layer for the knowledge-base app.
#
# A categorised, tagged, full-text-searchable store of markdown knowledge
# entries, backed by SQLite (FTS5) or PostgreSQL (tsvector). Portable CRUD runs
# through tclutils::tutdbc; only schema DDL and the full-text search are
# backend-specific and dispatched on the store's backend key.
#
# A "store" is a dict {conn <tdbc-conn> backend sqlite|postgres}. Callers open
# with kb::store::openSqlite / openPostgres and pass the store to every proc.

package require Tcl 8.6-
package require tclutils::tutdbc 0.1

namespace eval ::kb::store {
    namespace export openSqlite openPostgres close init \
        categoryAdd categories categoryEntries \
        entryAdd entryUpdate entryGet entryDelete entriesAll \
        tagEnsure entryTag entryUntag entryTags tagsAll pruneTags entriesByTag entriesByTags search \
        categoryMove categoryDescendants categoryPath categoryRename categoryDelete
    variable version 0.1
}

# --- open / close -----------------------------------------------------------
proc ::kb::store::openSqlite {file} {
    package require tdbc::sqlite3
    set conn [tdbc::sqlite3::connection new $file]
    catch {$conn allrows {PRAGMA foreign_keys = ON}}
    set store [dict create conn $conn backend sqlite]
    init $store
    return $store
}

proc ::kb::store::openPostgres {args} {
    package require tdbc::postgres
    set conn [tdbc::postgres::connection new {*}$args]
    set store [dict create conn $conn backend postgres]
    init $store
    return $store
}

proc ::kb::store::close {store} {
    catch {[dict get $store conn] close}
}

proc ::kb::store::_c {store} { return [dict get $store conn] }
proc ::kb::store::_be {store} { return [dict get $store backend] }

# --- schema (idempotent) ----------------------------------------------------
proc ::kb::store::init {store} {
    set c [_c $store]
    switch -- [_be $store] {
        sqlite   { _initSqlite $c }
        postgres { _initPostgres $c }
        default  { return -code error -errorcode {KB STORE BACKEND} \
                       "unknown backend [_be $store]" }
    }
}

proc ::kb::store::_initSqlite {c} {
    $c allrows {CREATE TABLE IF NOT EXISTS category (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL,
        parent_id INTEGER REFERENCES category(id), sort INTEGER DEFAULT 0)}
    $c allrows {CREATE TABLE IF NOT EXISTS entry (
        id INTEGER PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
        category_id INTEGER REFERENCES category(id), source TEXT,
        created TEXT DEFAULT (datetime('now')),
        updated TEXT DEFAULT (datetime('now')))}
    $c allrows {CREATE TABLE IF NOT EXISTS tag (
        id INTEGER PRIMARY KEY, name TEXT NOT NULL UNIQUE)}
    $c allrows {CREATE TABLE IF NOT EXISTS entry_tag (
        entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,
        tag_id INTEGER REFERENCES tag(id) ON DELETE CASCADE,
        PRIMARY KEY (entry_id, tag_id))}
    # FTS5 over title+body, external-content mirror of `entry`
    $c allrows {CREATE VIRTUAL TABLE IF NOT EXISTS entry_fts USING fts5(
        title, body, content='entry', content_rowid='id', tokenize='unicode61')}
    foreach trig {
        {CREATE TRIGGER IF NOT EXISTS entry_ai AFTER INSERT ON entry BEGIN
            INSERT INTO entry_fts(rowid,title,body) VALUES(new.id,new.title,new.body);
         END}
        {CREATE TRIGGER IF NOT EXISTS entry_ad AFTER DELETE ON entry BEGIN
            INSERT INTO entry_fts(entry_fts,rowid,title,body)
                VALUES('delete',old.id,old.title,old.body);
         END}
        {CREATE TRIGGER IF NOT EXISTS entry_au AFTER UPDATE ON entry BEGIN
            INSERT INTO entry_fts(entry_fts,rowid,title,body)
                VALUES('delete',old.id,old.title,old.body);
            INSERT INTO entry_fts(rowid,title,body) VALUES(new.id,new.title,new.body);
         END}
    } { $c allrows $trig }
}

proc ::kb::store::_initPostgres {c} {
    $c allrows {CREATE TABLE IF NOT EXISTS category (
        id SERIAL PRIMARY KEY, name TEXT NOT NULL,
        parent_id INTEGER REFERENCES category(id), sort INTEGER DEFAULT 0)}
    $c allrows {CREATE TABLE IF NOT EXISTS entry (
        id SERIAL PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL DEFAULT '',
        category_id INTEGER REFERENCES category(id), source TEXT,
        created TIMESTAMP DEFAULT now(), updated TIMESTAMP DEFAULT now(),
        tsv tsvector)}
    $c allrows {CREATE TABLE IF NOT EXISTS tag (
        id SERIAL PRIMARY KEY, name TEXT NOT NULL UNIQUE)}
    $c allrows {CREATE TABLE IF NOT EXISTS entry_tag (
        entry_id INTEGER REFERENCES entry(id) ON DELETE CASCADE,
        tag_id INTEGER REFERENCES tag(id) ON DELETE CASCADE,
        PRIMARY KEY (entry_id, tag_id))}
    # keep tsv in sync (title weighted higher than body) + GIN index
    $c allrows {CREATE OR REPLACE FUNCTION entry_tsv_update() RETURNS trigger AS $$
        BEGIN
            NEW.tsv := setweight(to_tsvector('german', coalesce(NEW.title,'')),'A')
                    || setweight(to_tsvector('german', coalesce(NEW.body,'')),'B');
            RETURN NEW;
        END $$ LANGUAGE plpgsql}
    catch {$c allrows {CREATE TRIGGER entry_tsv BEFORE INSERT OR UPDATE ON entry
        FOR EACH ROW EXECUTE FUNCTION entry_tsv_update()}}
    catch {$c allrows {CREATE INDEX entry_tsv_idx ON entry USING gin(tsv)}}
}

# --- categories -------------------------------------------------------------
proc ::kb::store::categoryAdd {store name {parent ""} {sort 0}} {
    set c [_c $store]
    set data [dict create name $name sort $sort]
    if {$parent ne ""} { dict set data parent_id $parent }
    ::tclutils::tutdbc::insert $c category $data
    return [_lastId $store category]
}

proc ::kb::store::categories {store} {
    return [::tclutils::tutdbc::rows [_c $store] \
        {SELECT id, name, parent_id, sort FROM category ORDER BY sort, name}]
}

# entries of a category INCLUDING all descendant subcategories (recursive).
# The WITH RECURSIVE walk over parent_id is portable across SQLite and Postgres.
proc ::kb::store::categoryEntries {store catId} {
    return [::tclutils::tutdbc::rows [_c $store] \
        {WITH RECURSIVE sub(id) AS (
            SELECT :cid
            UNION ALL
            SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id
         )
         SELECT id, title FROM entry
         WHERE category_id IN (SELECT id FROM sub) ORDER BY title} \
        [dict create cid $catId]]
}

# ids of all descendant categories of `catId` (excluding catId itself).
proc ::kb::store::categoryDescendants {store catId} {
    set out {}
    foreach r [::tclutils::tutdbc::rows [_c $store] \
        {WITH RECURSIVE sub(id) AS (
            SELECT :cid
            UNION ALL
            SELECT c.id FROM category c JOIN sub ON c.parent_id = sub.id
         )
         SELECT id FROM sub WHERE id <> :cid} [dict create cid $catId]] {
        lappend out [dict get $r id]
    }
    return $out
}

# "Bereich / Thema / ..." path for a category id ("" -> "").
proc ::kb::store::categoryPath {store id} {
    if {$id eq ""} { return "" }
    set c [_c $store]
    set parts {}
    set cur $id
    set guard 0
    while {$cur ne "" && [incr guard] < 200} {
        set row [lindex [::tclutils::tutdbc::rows $c \
            {SELECT name, parent_id FROM category WHERE id=:id} [dict create id $cur]] 0]
        if {$row eq ""} break
        set parts [linsert $parts 0 [dict get $row name]]
        set cur [dict get $row parent_id]
    }
    return [join $parts " / "]
}

# Re-parent a category: make `catId` a child of `newParent` ("" = top level).
# Guards against cycles (a category may not move under itself or a descendant).
proc ::kb::store::categoryMove {store catId newParent} {
    if {$newParent ne ""} {
        if {$newParent == $catId} {
            return -code error -errorcode {KB STORE CYCLE} \
                "a category cannot be its own parent"
        }
        if {$newParent in [categoryDescendants $store $catId]} {
            return -code error -errorcode {KB STORE CYCLE} \
                "cannot move a category under one of its own descendants"
        }
    }
    if {$newParent eq ""} {
        return [::tclutils::tutdbc::execute [_c $store] \
            {UPDATE category SET parent_id=NULL WHERE id=:id} [dict create id $catId]]
    }
    return [::tclutils::tutdbc::execute [_c $store] \
        {UPDATE category SET parent_id=:p WHERE id=:id} \
        [dict create id $catId p $newParent]]
}

# Rename a category.
proc ::kb::store::categoryRename {store catId name} {
    return [::tclutils::tutdbc::execute [_c $store] \
        {UPDATE category SET name=:n WHERE id=:id} [dict create id $catId n $name]]
}

# Delete a category. Its direct children are re-parented to its own parent, and
# its entries move to that parent too (NULL = top level / uncategorised), so
# nothing is orphaned. Runs in a transaction.
proc ::kb::store::categoryDelete {store catId} {
    set c [_c $store]
    set parent [::tclutils::tutdbc::value $c \
        {SELECT parent_id FROM category WHERE id=:id} [dict create id $catId]]
    ::tclutils::tutdbc::transaction $c {
        if {$parent eq ""} {
            ::tclutils::tutdbc::execute $c \
                {UPDATE category SET parent_id=NULL WHERE parent_id=:id} [dict create id $catId]
            ::tclutils::tutdbc::execute $c \
                {UPDATE entry SET category_id=NULL WHERE category_id=:id} [dict create id $catId]
        } else {
            ::tclutils::tutdbc::execute $c \
                {UPDATE category SET parent_id=:p WHERE parent_id=:id} \
                [dict create id $catId p $parent]
            ::tclutils::tutdbc::execute $c \
                {UPDATE entry SET category_id=:p WHERE category_id=:id} \
                [dict create id $catId p $parent]
        }
        ::tclutils::tutdbc::execute $c \
            {DELETE FROM category WHERE id=:id} [dict create id $catId]
    }
    return 1
}

# --- entries ----------------------------------------------------------------
proc ::kb::store::entryAdd {store title body {category ""} {source ""}} {
    set c [_c $store]
    set data [dict create title $title body $body]
    if {$category ne ""} { dict set data category_id $category }
    if {$source   ne ""} { dict set data source      $source   }
    ::tclutils::tutdbc::insert $c entry $data
    return [_lastId $store entry]
}

proc ::kb::store::entryUpdate {store id title body {category ""}} {
    set c [_c $store]
    set binds [dict create id $id title $title body $body cat $category]
    if {$category eq ""} {
        ::tclutils::tutdbc::execute $c {UPDATE entry
            SET title=:title, body=:body, category_id=NULL, updated=:now
            WHERE id=:id} [dict create id $id title $title body $body now [_now]]
    } else {
        ::tclutils::tutdbc::execute $c {UPDATE entry
            SET title=:title, body=:body, category_id=:cat, updated=:now
            WHERE id=:id} [dict create id $id title $title body $body cat $category now [_now]]
    }
}

proc ::kb::store::entryGet {store id} {
    set r [::tclutils::tutdbc::rows [_c $store] \
        {SELECT id, title, body, category_id, source, created, updated
         FROM entry WHERE id=:id} [dict create id $id]]
    return [lindex $r 0]
}

proc ::kb::store::entryDelete {store id} {
    ::tclutils::tutdbc::execute [_c $store] \
        {DELETE FROM entry WHERE id=:id} [dict create id $id]
}

proc ::kb::store::entriesAll {store} {
    return [::tclutils::tutdbc::rows [_c $store] \
        {SELECT id, title, category_id FROM entry ORDER BY title}]
}

# --- tags -------------------------------------------------------------------
proc ::kb::store::tagEnsure {store name} {
    set c [_c $store]
    set id [::tclutils::tutdbc::value $c {SELECT id FROM tag WHERE name=:n} \
        [dict create n $name]]
    if {$id ne ""} { return $id }
    ::tclutils::tutdbc::insert $c tag [dict create name $name]
    return [_lastId $store tag]
}

proc ::kb::store::entryTag {store entryId name} {
    set c [_c $store]
    set tid [tagEnsure $store $name]
    # INSERT OR IGNORE / ON CONFLICT DO NOTHING, backend-specific
    if {[_be $store] eq "sqlite"} {
        ::tclutils::tutdbc::execute $c \
            {INSERT OR IGNORE INTO entry_tag(entry_id,tag_id) VALUES(:e,:t)} \
            [dict create e $entryId t $tid]
    } else {
        ::tclutils::tutdbc::execute $c \
            {INSERT INTO entry_tag(entry_id,tag_id) VALUES(:e,:t)
             ON CONFLICT DO NOTHING} [dict create e $entryId t $tid]
    }
    return $tid
}

proc ::kb::store::entryUntag {store entryId name} {
    ::tclutils::tutdbc::execute [_c $store] \
        {DELETE FROM entry_tag WHERE entry_id=:e AND tag_id=
            (SELECT id FROM tag WHERE name=:n)} \
        [dict create e $entryId n $name]
}

proc ::kb::store::entryTags {store entryId} {
    set out {}
    foreach r [::tclutils::tutdbc::rows [_c $store] \
        {SELECT t.name AS name FROM tag t JOIN entry_tag et ON et.tag_id=t.id
         WHERE et.entry_id=:e ORDER BY t.name} [dict create e $entryId]] {
        lappend out [dict get $r name]
    }
    return $out
}

proc ::kb::store::tagsAll {store} {
    set out {}
    foreach r [::tclutils::tutdbc::rows [_c $store] \
        {SELECT DISTINCT t.name FROM tag t
         JOIN entry_tag et ON et.tag_id = t.id ORDER BY t.name}] {
        lappend out [dict get $r name]
    }
    return $out
}

# remove tag rows no entry references any more; returns the number removed.
proc ::kb::store::pruneTags {store} {
    return [::tclutils::tutdbc::execute [_c $store] \
        {DELETE FROM tag WHERE id NOT IN (SELECT tag_id FROM entry_tag)}]
}

# all entries carrying a given tag (across categories) -> {id title category_id}
proc ::kb::store::entriesByTag {store tag} {
    return [::tclutils::tutdbc::rows [_c $store] \
        {SELECT e.id, e.title, e.category_id FROM entry e
         JOIN entry_tag et ON et.entry_id = e.id
         JOIN tag t ON t.id = et.tag_id
         WHERE t.name = :tag ORDER BY e.title} [dict create tag $tag]]
}

# entries matching several tags. mode "all" = carry every tag (AND),
# mode "any" = carry at least one (OR). Empty tag list -> all entries.
proc ::kb::store::entriesByTags {store tags {mode all}} {
    if {[llength $tags] == 0} { return [entriesAll $store] }
    set binds [dict create]
    set phs {}
    set i 0
    foreach t $tags { lappend phs ":t$i"; dict set binds t$i $t; incr i }
    set inlist [join $phs ,]
    if {$mode eq "any"} {
        set sql "SELECT DISTINCT e.id, e.title, e.category_id FROM entry e
                 JOIN entry_tag et ON et.entry_id = e.id
                 JOIN tag t ON t.id = et.tag_id
                 WHERE t.name IN ($inlist) ORDER BY e.title"
    } else {
        set n [llength $tags]
        set sql "SELECT e.id, e.title, e.category_id FROM entry e
                 WHERE (SELECT count(DISTINCT t.name) FROM entry_tag et
                        JOIN tag t ON t.id = et.tag_id
                        WHERE et.entry_id = e.id AND t.name IN ($inlist)) = $n
                 ORDER BY e.title"
    }
    return [::tclutils::tutdbc::rows [_c $store] $sql $binds]
}

# --- full-text search -------------------------------------------------------
# Returns a list of dicts {id title snippet} ranked by relevance. Optional
# -category / -tag filters narrow the result.
proc ::kb::store::search {store query args} {
    set catId ""; set tag ""
    foreach {k v} $args {
        switch -- $k { -category {set catId $v} -tag {set tag $v} }
    }
    if {[_be $store] eq "sqlite"} {
        return [_searchSqlite $store $query $catId $tag]
    }
    return [_searchPostgres $store $query $catId $tag]
}

proc ::kb::store::_searchSqlite {store query catId tag} {
    set binds [dict create q $query]
    set where [list {entry_fts MATCH :q}]
    if {$catId ne ""} { lappend where {e.category_id=:cid}; dict set binds cid $catId }
    if {$tag ne ""} {
        lappend where {e.id IN (SELECT et.entry_id FROM entry_tag et
            JOIN tag t ON t.id=et.tag_id WHERE t.name=:tag)}
        dict set binds tag $tag
    }
    set sql "SELECT e.id AS id, e.title AS title,
                    snippet(entry_fts,1,'\[','\]','…',12) AS snippet
             FROM entry_fts JOIN entry e ON e.id=entry_fts.rowid
             WHERE [join $where { AND }] ORDER BY rank"
    return [::tclutils::tutdbc::rows [_c $store] $sql $binds]
}

proc ::kb::store::_searchPostgres {store query catId tag} {
    set binds [dict create q $query]
    set where {e.tsv @@ websearch_to_tsquery('german', :q)}
    if {$catId ne ""} { append where { AND e.category_id=:cid}; dict set binds cid $catId }
    if {$tag ne ""} {
        append where { AND e.id IN (SELECT et.entry_id FROM entry_tag et
            JOIN tag t ON t.id=et.tag_id WHERE t.name=:tag)}
        dict set binds tag $tag
    }
    set sql "SELECT e.id AS id, e.title AS title,
                    ts_headline('german', e.body,
                        websearch_to_tsquery('german', :q)) AS snippet
             FROM entry e WHERE $where
             ORDER BY ts_rank(e.tsv, websearch_to_tsquery('german', :q)) DESC"
    return [::tclutils::tutdbc::rows [_c $store] $sql $binds]
}

# --- helpers ----------------------------------------------------------------
proc ::kb::store::_now {} { return [clock format [clock seconds] -format "%Y-%m-%d %H:%M:%S"] }

# last generated id, backend-specific
proc ::kb::store::_lastId {store table} {
    set c [_c $store]
    if {[_be $store] eq "sqlite"} {
        return [::tclutils::tutdbc::value $c {SELECT last_insert_rowid()}]
    }
    return [::tclutils::tutdbc::value $c "SELECT currval(pg_get_serial_sequence('$table','id'))"]
}

package provide kb::store 0.1
