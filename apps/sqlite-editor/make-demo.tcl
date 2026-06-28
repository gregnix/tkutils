package require sqlite3
set f [file join [file dirname [info script]] demo.db]
file delete -force $f
sqlite3 db $f
db eval {CREATE TABLE people (id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL, age INTEGER)}
db eval {INSERT INTO people (name,age) VALUES ('Alice',30),('Bob',7),('Cara',54)}
db eval {CREATE INDEX idx_people_age ON people(age)}
db eval {CREATE VIEW adults AS SELECT name,age FROM people WHERE age>=18}
db close
puts "wrote $f"
