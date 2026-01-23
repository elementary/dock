/*
 * SPDX-License-Identifier: GPL-3.0
 * SPDX-FileCopyrightText: 2025 elementary, Inc. (https://elementary.io)
 *
 * Authored by: Leonhard Kargl <leo.kargl@proton.me>
 */

 public class Dock.ItemGroup : Gtk.Fixed {
    private const string OBJECT_DATA_KEY = "item-group-obj";

    [CCode (has_target = false)]
    public delegate BaseItem CreateBaseItemFunc (Object obj);

    private static Settings settings;

    public ListModel items { get; construct; }
    public CreateBaseItemFunc create_item_func { get; construct; }

    private Sequence<BaseItem> item_store;
    private ListStore current_children;

    private Adw.TimedAnimation resize_animation;

    private bool relayout_queued = false;

    private HashTable<Object, BaseItem> cached_items;
    private uint clear_cache_id = 0;

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

        cached_items = new HashTable<Object, BaseItem> (null, null);
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
        start_iter.foreach_range (end_iter, cache_item);
        start_iter.foreach_range (end_iter, remove_item);
        start_iter.remove_range (end_iter);

        var insert_iter = item_store.get_iter_at_pos ((int) position);
        for (int i = (int) position; i < position + added; i++) {
            var item = get_or_create_item (items.get_item (i));
            insert_iter.insert_before (item);

            add_item (i, item);
        }
    }

    // Make sure that if an item is removed and added again in the same
    // mainloop iteration it gets mapped to the same BaseItem
    private void cache_item (BaseItem item) {
        cached_items[item.get_data<Object> (OBJECT_DATA_KEY)] = item;

        if (clear_cache_id == 0) {
            clear_cache_id = Idle.add_once (clear_cache);
        }
    }

    private void clear_cache () {
        cached_items.remove_all ();
        clear_cache_id = 0;
    }

    private BaseItem get_or_create_item (Object obj) {
        if (obj in cached_items) {
            return cached_items[obj];
        }

        var base_item = create_item_func (obj);
        base_item.set_data<Object> (OBJECT_DATA_KEY, obj);
        return base_item;
    }

    private void add_item (int pos, BaseItem item) {
        if (item.parent == this) {
            // The item was already in this group and is currently being removed
            // so immediately finish the removal and add it as if it was new
            // This happens when the items are repositioned via dnd
            finish_remove (item);
        }

        item.visible = false;

        var item_pos = get_launcher_size () * pos;
        put (item, item_pos, 0);
        item.current_pos = item_pos;

        current_children.insert (pos, item);
    }

    private void remove_item (BaseItem item) {
        item.revealed_done.connect (finish_remove);
        item.set_revealed (false);

        cached_items[item.get_data<Object> ("dock-obj")] = item;
    }

    private void finish_remove (BaseItem item) {
        item.revealed_done.disconnect (finish_remove);

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
