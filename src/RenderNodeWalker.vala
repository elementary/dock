// TODO: Copyright

public class Dock.RenderNodeWalker : GLib.Object {
    public static int? get_first_border_radius (Gsk.RenderNode main_node, out int depth) {
        depth = 0;

        var main_node_type = main_node.get_node_type ();

        if (main_node_type == Gsk.RenderNodeType.ROUNDED_CLIP_NODE) {
            return (int) ((Gsk.RoundedClipNode) main_node).get_clip ().corner[0].width;
        }

        depth++;

        if (main_node_type == Gsk.RenderNodeType.CONTAINER_NODE) {
            var container_node = (Gsk.ContainerNode) main_node;

            var min_child_depth = int.MAX;
            int? min_border_radius = null;

            for (var i =  0; i < container_node.get_n_children (); i++) {
                var child_node = container_node.get_child (i);

                int child_depth;
                var border_radius = get_first_border_radius (child_node, out child_depth);
                
                if (child_depth < min_child_depth && border_radius != null) {
                    min_child_depth = child_depth;
                    min_border_radius = border_radius;
                }
            }

            depth += min_child_depth;
            return min_border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.GL_SHADER_NODE) {
            var gl_shader_node = (Gsk.GLShaderNode) main_node;

            var min_child_depth = int.MAX;
            int? min_border_radius = null;

            for (var i =  0; i < gl_shader_node.get_n_children (); i++) {
                var child_node = gl_shader_node.get_child (i);

                int child_depth;
                var border_radius = get_first_border_radius (child_node, out child_depth);

                if (child_depth < min_child_depth && border_radius != null) {
                    min_child_depth = child_depth;
                    min_border_radius = border_radius;
                }
            }

            depth += min_child_depth;
            return min_border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.TRANSFORM_NODE) {
            var child_node = ((Gsk.TransformNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.OPACITY_NODE) {
            var child_node = ((Gsk.OpacityNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.COLOR_MATRIX_NODE) {
            var child_node = ((Gsk.ColorMatrixNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.REPEAT_NODE) {
            var child_node = ((Gsk.RepeatNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.CLIP_NODE) {
            var child_node = ((Gsk.ClipNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.SHADOW_NODE) {
            var child_node = ((Gsk.ShadowNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.BLUR_NODE) {
            var child_node = ((Gsk.BlurNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.DEBUG_NODE) {
            var child_node = ((Gsk.DebugNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.FILL_NODE) {
            var child_node = ((Gsk.FillNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.STROKE_NODE) {
            var child_node = ((Gsk.StrokeNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        if (main_node_type == Gsk.RenderNodeType.SUBSURFACE_NODE) {
            var child_node = ((Gsk.SubsurfaceNode) main_node).get_child ();

            int child_depth;
            var border_radius = get_first_border_radius (child_node, out child_depth);

            if (border_radius != null) {
                depth += child_depth;
            }

            return border_radius;
        }

        return null;
    }
}
