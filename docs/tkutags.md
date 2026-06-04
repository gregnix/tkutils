# tkutils::tkutags

Tag editor: tags render as removable chips (label + "×"), with an input row to
add new ones (a combobox when `-suggestions` are given, otherwise an entry;
Return or "+" adds). Duplicates and blank tags are ignored. With `-readonly`
the input row and remove buttons are omitted.

## API

```tcl
set w [::tkutils::tkutags::widget .t ?-tags list? ?-suggestions list? \
        ?-textvariable var? ?-readonly bool? ?-command cmd?]
::tkutils::tkutags::getTags   $w
::tkutils::tkutags::setTags   $w list
::tkutils::tkutags::addTag    $w tag
::tkutils::tkutags::removeTag $w tag
::tkutils::tkutags::clear     $w
```

`-textvariable` mirrors the tag list (and seeds the initial tags if `-tags` is
empty). `-command` is called with the tag list whenever it changes.
