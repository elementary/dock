/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Dock.ItemGroup : Gtk.Fixed {
    [CCode (has_target = false)]
    public delegate BaseItem CreateBaseItemFunc (Object obj);

    private static Settings settings;

    public ListModel items { get; construct; }
    public CreateBaseItemFunc create_item_func { get; construct; }

    private Sequence<BaseItem> item_store;
    private ListStore current_children;

    private Adw.TimedAnimation resize_animation;

    private bool relayout_queued = false;

    private HashTable<Object, BaseItem> obj_to_item_table = new HashTable<Object, BaseItem> (null, null);
    private HashTable<BaseItem, Object> item_to_obj_table = new HashTable<BaseItem, Object> (null, null);

    private GenericSet<BaseItem> items_marked_for_removal = new GenericSet<BaseItem> (null, null);
    private uint remove_items_id = 0;

    public ItemGroup (ListModel items, CreateBaseItemFunc create_item_func) {
        Object (items: items, create_item_func: create_item_func);
    }

    static construct {
        settings = new Settings ("io.elementary.dock");
    }

    construct {
        item_store = new Sequence<BaseItem> ();

        current_children = new ListStore (typeof (BaseItem));
        current_children.items_changed.connect (queue_relayout);

        settings.changed["icon-size"].connect (queue_relayout);

        var animation_target = new Adw.PropertyAnimationTarget (this, "width-request");

        resize_animation = new Adw.TimedAnimation (this, 0, 0, Granite.TRANSITION_DURATION_OPEN, animation_target);
        resize_animation.done.connect (on_resized);

        items.items_changed.connect (on_items_changed);
        on_items_changed (0, 0, items.get_n_items ());

        overflow = VISIBLE;
    }

    private void queue_relayout () {
        if (relayout_queued) {
            return;
        }

        relayout_queued = true;
        Idle.add_once (relayout);
    }

    private void relayout () {
        resize_animation.value_from = width_request;
        resize_animation.value_to = get_launcher_size () * current_children.get_n_items ();
        resize_animation.duration = resize_animation.value_from < resize_animation.value_to ?
            Granite.TRANSITION_DURATION_OPEN : Granite.TRANSITION_DURATION_CLOSE;
        resize_animation.play ();

        for (uint i = 0; i < current_children.get_n_items (); i++) {
            var item = (BaseItem) current_children.get_item (i);
            item.animate_move (get_launcher_size () * i);

            /* Index might have changed so notify */
            item.notify_property ("index");
        }

        relayout_queued = false;
    }

    private static int get_launcher_size () {
        return settings.get_int ("icon-size") + Launcher.PADDING * 2;
    }

    private void on_resized () {
        // When we finished resizing we know we now have enough space for all new items
        // so reveal them
        for (uint i = 0; i < current_children.get_n_items (); i++) {
            var item = (BaseItem) current_children.get_item (i);
            if (!item.visible) {
                item.visible = true;
                item.set_revealed (true);
            }
        }
    }

    private void on_items_changed (uint position, uint removed, uint added) {
        var start_iter = item_store.get_iter_at_pos ((int) position);
        var end_iter = start_iter.move ((int) removed);
        start_iter.foreach_range (end_iter, mark_item_for_removal);
        start_iter.remove_range (end_iter);

        var insert_iter = item_store.get_iter_at_pos ((int) position);
        for (int i = (int) position; i < position + added; i++) {
            var item = get_or_create_item (items.get_item (i));
            insert_iter.insert_before (item);

            unmark_item_for_removal (item);
            add_item (i, item);
        }
    }

    /*
     * During drag-and-drop we get 2 separate item_changed signals:
     * 1 for removing the dragged item, and 1 for adding it back into new place.
     * To avoid removing this item, we remove it in Idle.
     */
    private void mark_item_for_removal (BaseItem item) {
        items_marked_for_removal.add (item);

        item.revealed_done.connect (remove_item);
        item.set_revealed (false);

        if (remove_items_id == 0) {
            remove_items_id = Idle.add_once (remove_pending_items);
        }
    }

    private void remove_pending_items () {
        remove_items_id = 0;

        foreach (var item in items_marked_for_removal.get_values ()) {
            item.cleanup ();
            items_marked_for_removal.remove (item);

            var obj = item_to_obj_table[item];
            obj_to_item_table.remove (obj);
            item_to_obj_table.remove (item);
        }
    }

    private void unmark_item_for_removal (BaseItem item) {
        items_marked_for_removal.remove (item);

        item.revealed_done.disconnect (remove_item);
        item.set_revealed (true);

    }

    private BaseItem get_or_create_item (Object obj) {
        if (obj in obj_to_item_table) {
            return obj_to_item_table[obj];
        }

        var base_item = create_item_func (obj);
        obj_to_item_table[obj] = base_item;
        item_to_obj_table[base_item] = obj;
        return base_item;
    }

    private void add_item (int pos, BaseItem item) {
        if (item.parent == this) {
            // The item was already in this group and is currently being removed
            // so immediately finish the removal and add it as if it was new
            // This happens when the items are repositioned via dnd
            remove_item (item);
        }

        item.visible = false;

        var item_pos = get_launcher_size () * pos;
        put (item, item_pos, 0);
        item.current_pos = item_pos;

        current_children.insert (pos, item);
    }

    private void remove_item (BaseItem item) {
        item.revealed_done.disconnect (remove_item);

        remove (item);

        uint index;
        if (current_children.find (item, out index)) {
            current_children.remove (index);
        }
    }

    public uint get_index_for_item (BaseItem item) {
        uint index;
        if (current_children.find (item, out index)) {
            return index;
        }

        return Gtk.INVALID_LIST_POSITION;
    }
}
