#include "my_application.h"

#include <flutter_linux/flutter_linux.h>
#ifdef GDK_WINDOWING_X11
#include <gdk/gdkx.h>
#endif

#include "flutter/generated_plugin_registrant.h"

struct _MyApplication {
  GtkApplication parent_instance;
  char** dart_entrypoint_arguments;
  FlView* main_view;
  FlMethodChannel* window_channel;
};

G_DEFINE_TYPE(MyApplication, my_application, GTK_TYPE_APPLICATION)

// Called when first Flutter frame received.
static guint32 global_last_user_time = 0; // GDK_CURRENT_TIME is 0

static gboolean on_app_input_event(GtkWidget *widget, GdkEvent *event, gpointer data) {
  guint32 time = gdk_event_get_time(event);
  if (time != 0) { // 0 is GDK_CURRENT_TIME
    global_last_user_time = time;
  }
  return FALSE; // Continue propagating the event to Flutter
}

static void first_frame_cb(MyApplication* self, FlView* view) {
  gtk_widget_show(gtk_widget_get_toplevel(GTK_WIDGET(view)));
}

// Callback when first Flutter frame is received for secondary windows
static void secondary_first_frame_cb(MyApplication* self, FlView* view) {
  GtkWidget* window = gtk_widget_get_toplevel(GTK_WIDGET(view));
  if (GTK_IS_WINDOW(window)) {
    // If we marked this window to be maximized, do it right before showing
    gpointer should_maximize = g_object_get_data(G_OBJECT(window), "maximize");
    if (should_maximize) {
      gtk_window_maximize(GTK_WINDOW(window));
    }

    gtk_widget_show(window);
    
    // Present the window using the last known user interaction timestamp.
    // This provides the Window Manager (GNOME/Mutter) with proof that this
    // window was spawned by a recent user action, granting it immediate focus.
    gtk_window_present_with_time(GTK_WINDOW(window), global_last_user_time);
    gtk_widget_grab_focus(GTK_WIDGET(view));
    
    // Explicitly notify Dart that this window now has focus natively
    if (self && self->window_channel) {
      int64_t view_id = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(window), "view_id"));
      g_autoptr(FlValue) args = fl_value_new_map();
      fl_value_set_string_take(args, "view_id", fl_value_new_int(view_id));
      fl_method_channel_invoke_method(self->window_channel, "on_window_focus", args, nullptr, nullptr, nullptr);
    }
  }
}

// Window destroy callback for secondary windows
static void on_secondary_window_destroy(GtkWidget* widget, gpointer data) {
  // We don't need to do anything specific here, GTK handles widget destruction.
  // Dart side will observe the view being removed.
}

static gboolean on_secondary_window_delete(GtkWidget* widget, GdkEvent* event, gpointer data) {
  MyApplication* app = MY_APPLICATION(g_application_get_default());
  if (app && app->window_channel) {
    int64_t view_id = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(widget), "view_id"));
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "view_id", fl_value_new_int(view_id));
    fl_method_channel_invoke_method(app->window_channel, "on_window_close", args, nullptr, nullptr, nullptr);
  }
  // Return TRUE to prevent GTK from destroying the window immediately.
  // Dart side will call close_window to cleanly destroy it.
  return TRUE;
}


static gboolean on_secondary_window_focus_in(GtkWidget* widget, GdkEventFocus* event, gpointer data) {
  GtkWidget* child_view = GTK_WIDGET(data);
  if (child_view && GTK_IS_WIDGET(child_view)) {
    gtk_widget_grab_focus(child_view);
  }
  
  MyApplication* app = MY_APPLICATION(g_application_get_default());
  if (app && app->window_channel) {
    int64_t view_id = GPOINTER_TO_INT(g_object_get_data(G_OBJECT(widget), "view_id"));
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "view_id", fl_value_new_int(view_id));
    fl_method_channel_invoke_method(app->window_channel, "on_window_focus", args, nullptr, nullptr, nullptr);
  }
  return FALSE;
}

static gboolean on_main_window_focus_in(GtkWidget* widget, GdkEventFocus* event, gpointer data) {
  MyApplication* app = MY_APPLICATION(g_application_get_default());
  if (app && app->window_channel && app->main_view) {
    int64_t view_id = fl_view_get_id(app->main_view);
    g_autoptr(FlValue) args = fl_value_new_map();
    fl_value_set_string_take(args, "view_id", fl_value_new_int(view_id));
    fl_method_channel_invoke_method(app->window_channel, "on_window_focus", args, nullptr, nullptr, nullptr);
  }
  return FALSE;
}

static GtkWindow* get_window_by_view_id(MyApplication* self, int64_t target_id) {
  if (target_id == fl_view_get_id(self->main_view)) {
    GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
    if (windows) return GTK_WINDOW(windows->data);
  } else {
    GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
    for (GList* l = windows; l != nullptr; l = l->next) {
      GtkWindow* w = GTK_WINDOW(l->data);
      gpointer data = g_object_get_data(G_OBJECT(w), "view_id");
      if (data && GPOINTER_TO_INT(data) == target_id) {
        return w;
      }
    }
  }
  return nullptr;
}

static void window_method_call_handler(FlMethodChannel* channel, FlMethodCall* method_call, gpointer user_data) {
  MyApplication* self = MY_APPLICATION(user_data);
  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "create_window") == 0) {
    if (!self->main_view) {
       fl_method_call_respond_error(method_call, "ERROR", "Main view not initialized", nullptr, nullptr);
       return;
    }
    
    int width = 800;
    int height = 600;
    bool maximize = false;
    
    FlValue* args = fl_method_call_get_args(method_call);
    if (args != nullptr && fl_value_get_type(args) == FL_VALUE_TYPE_MAP) {
      FlValue* w_val = fl_value_lookup_string(args, "width");
      if (w_val && fl_value_get_type(w_val) == FL_VALUE_TYPE_INT) {
        width = fl_value_get_int(w_val);
      }
      FlValue* h_val = fl_value_lookup_string(args, "height");
      if (h_val && fl_value_get_type(h_val) == FL_VALUE_TYPE_INT) {
        height = fl_value_get_int(h_val);
      }
      FlValue* max_val = fl_value_lookup_string(args, "maximize");
      if (max_val && fl_value_get_type(max_val) == FL_VALUE_TYPE_BOOL) {
        maximize = fl_value_get_bool(max_val);
      }
    }
    
    FlEngine* engine = fl_view_get_engine(self->main_view);
    FlView* new_view = fl_view_new_for_engine(engine);
    
    GtkWindow* new_window = GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(self)));
    gtk_window_set_title(new_window, "onyxcore Secondary");
    gtk_window_set_default_size(new_window, width, height);
    
    if (maximize) {
      // Delay maximizing until first-frame to prevent OpenGL sizing race conditions
      g_object_set_data(G_OBJECT(new_window), "maximize", GINT_TO_POINTER(1));
    }
    
    gtk_widget_show(GTK_WIDGET(new_view));
    // FIX: Set a minimum size request on the FlView so its GL context is
    // initialized with a reasonable allocation rather than a tiny default.
    // Without this, the compositor shader setup can fail with
    // "unable to make OpenGL context current" on slow GPU systems because
    // the FlView gets realized with a 0×0 or small allocation.
    gtk_widget_set_size_request(GTK_WIDGET(new_view), width, height);
    gtk_container_add(GTK_CONTAINER(new_window), GTK_WIDGET(new_view));
    
    g_signal_connect(new_window, "destroy", G_CALLBACK(on_secondary_window_destroy), nullptr);
    g_signal_connect(new_window, "delete-event", G_CALLBACK(on_secondary_window_delete), nullptr);
    g_signal_connect(new_window, "focus-in-event", G_CALLBACK(on_secondary_window_focus_in), new_view);
    g_signal_connect_swapped(new_view, "first-frame", G_CALLBACK(secondary_first_frame_cb), self);
    // Let GTK's natural mapping cycle handle realization after the view is
    // added to the container and has a proper allocation.  Calling
    // gtk_widget_realize() immediately was racing with the compositor shader
    // setup on systems with slow GPU initialization (software Mesa).
    gtk_widget_realize(GTK_WIDGET(new_view));

    
    int64_t view_id = fl_view_get_id(new_view);
    g_object_set_data(G_OBJECT(new_window), "view_id", GINT_TO_POINTER((int)view_id));
    
    g_autoptr(FlValue) result = fl_value_new_int(view_id);
    fl_method_call_respond_success(method_call, result, nullptr);
  } else if (strcmp(method, "set_fullscreen") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* view_id_val = fl_value_lookup_string(args, "view_id");
    FlValue* is_full_val = fl_value_lookup_string(args, "is_fullscreen");
    
    if (view_id_val && is_full_val && fl_value_get_type(view_id_val) == FL_VALUE_TYPE_INT && fl_value_get_type(is_full_val) == FL_VALUE_TYPE_BOOL) {
      int64_t target_id = fl_value_get_int(view_id_val);
      bool is_full = fl_value_get_bool(is_full_val);
      
      GtkWindow* target_window = get_window_by_view_id(self, target_id);
      
      if (target_window) {
        if (is_full) {
          gtk_window_fullscreen(target_window);
        } else {
          gtk_window_unfullscreen(target_window);
        }
        fl_method_call_respond_success(method_call, nullptr, nullptr);
      } else {
        fl_method_call_respond_error(method_call, "ERROR", "Window not found", nullptr, nullptr);
      }
    } else {
      fl_method_call_respond_error(method_call, "ERROR", "Invalid arguments", nullptr, nullptr);
    }
  } else if (strcmp(method, "present_window") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* view_id_val = fl_value_lookup_string(args, "view_id");
    
    if (view_id_val && fl_value_get_type(view_id_val) == FL_VALUE_TYPE_INT) {
      int64_t target_id = fl_value_get_int(view_id_val);
      
      GtkWindow* target_window = get_window_by_view_id(self, target_id);
      if (target_window) {
        gtk_window_present_with_time(target_window, global_last_user_time);
        // Also grab focus for the child view if it exists
        GtkWidget* child = gtk_bin_get_child(GTK_BIN(target_window));
        if (child && GTK_IS_WIDGET(child)) {
          gtk_widget_grab_focus(child);
        }
        fl_method_call_respond_success(method_call, nullptr, nullptr);
      } else {
        fl_method_call_respond_error(method_call, "ERROR", "Window not found", nullptr, nullptr);
      }
    } else {
      fl_method_call_respond_error(method_call, "ERROR", "Invalid arguments", nullptr, nullptr);
    }
  } else if (strcmp(method, "close_window") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    FlValue* view_id_val = fl_value_lookup_string(args, "view_id");
    
    if (view_id_val && fl_value_get_type(view_id_val) == FL_VALUE_TYPE_INT) {
      int64_t target_id = fl_value_get_int(view_id_val);
      
      GtkWindow* target_window = get_window_by_view_id(self, target_id);
      if (target_window) {
        // FIX: Hide the window first to stop the Flutter engine from rendering
        // into this FlView's GL context. Then schedule the actual destruction
        // on a deferred timer so the engine has time to stop its render loop.
        // Direct gtk_widget_destroy() was racing with active GL rendering and
        // causing segfaults on systems with slow GPU teardown (e.g. Linux Mint
        // with software Mesa / AMD iGPU).
        gtk_widget_hide(GTK_WIDGET(target_window));
        
        // prevent delete-event from firing again during deferred destruction
        g_signal_handlers_disconnect_by_func(target_window,
            (gpointer)on_secondary_window_delete, nullptr);
        
        // prevent destroy handler from firing during deferred destruction
        g_signal_handlers_disconnect_by_func(target_window,
            (gpointer)on_secondary_window_destroy, nullptr);
        
        // prevent focus-in handler from firing on a dying window
        g_signal_handlers_disconnect_matched(target_window,
            G_SIGNAL_MATCH_FUNC, 0, 0, nullptr,
            (gpointer)on_secondary_window_focus_in, nullptr);
        
        // prevent first-frame handler from firing on a dying view
        GtkWidget* child_view = gtk_bin_get_child(GTK_BIN(target_window));
        if (child_view && GTK_IS_WIDGET(child_view)) {
          g_signal_handlers_disconnect_matched(child_view,
              G_SIGNAL_MATCH_FUNC, 0, 0, nullptr,
              (gpointer)secondary_first_frame_cb, nullptr);
        }
        
        // prevent focus from going to the dying window
        GList* windows = gtk_application_get_windows(GTK_APPLICATION(self));
        if (windows) {
          for (GList* l = windows; l != nullptr; l = l->next) {
            GtkWindow* w = GTK_WINDOW(l->data);
            if (w != target_window && gtk_widget_get_visible(GTK_WIDGET(w))) {
              gtk_window_present(w);
              break;
            }
          }
        }
        
        // prevent the reference from being freed before deferred destroy
        g_object_ref(target_window);
        
        // Deferred destruction: destroy the window after 200ms to let the
        // Flutter engine fully stop rendering into its GL context.
        g_timeout_add(200, [](gpointer data) -> gboolean {
          GtkWidget* widget = GTK_WIDGET(data);
          if (GTK_IS_WIDGET(widget)) {
            gtk_widget_destroy(widget);
          }
          g_object_unref(data);
          return G_SOURCE_REMOVE;
        }, target_window);
        
        fl_method_call_respond_success(method_call, nullptr, nullptr);
      } else {
        fl_method_call_respond_error(method_call, "ERROR", "Window not found", nullptr, nullptr);
      }
    } else {
      fl_method_call_respond_error(method_call, "ERROR", "Invalid arguments", nullptr, nullptr);
    }
  } else {
    fl_method_call_respond_not_implemented(method_call, nullptr);
  }
}

// Implements GApplication::activate.
static void my_application_activate(GApplication* application) {
  MyApplication* self = MY_APPLICATION(application);
  GtkWindow* window =
      GTK_WINDOW(gtk_application_window_new(GTK_APPLICATION(application)));

  // Use a header bar when running in GNOME as this is the common style used
  // by applications and is the setup most users will be using (e.g. Ubuntu
  // desktop).
  // If running on X and not using GNOME then just use a traditional title bar
  // in case the window manager does more exotic layout, e.g. tiling.
  // If running on Wayland assume the header bar will work (may need changing
  // if future cases occur).
  gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#endif
  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "onyxcore");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "onyxcore");
  }

  gtk_window_set_default_size(window, 1280, 720);

  // Set the application window icon from the bundled PNG.
  // This icon appears in taskbars, alt-tab switchers, and window decorations.
  {
    g_autofree gchar* exec_path = g_file_read_link("/proc/self/exe", nullptr);
    if (exec_path) {
      g_autofree gchar* exec_dir = g_path_get_dirname(exec_path);
      g_autofree gchar* icon_path = g_build_filename(exec_dir, "data", "flutter_assets", "assets", "app_icon", "app_icon.svg", nullptr);
      // Try SVG path first; fall back to the PNG placed next to the binary
      g_autofree gchar* png_path = g_build_filename(exec_dir, "app_icon.png", nullptr);
      GError* icon_error = nullptr;
      if (!gtk_window_set_icon_from_file(window, icon_path, &icon_error)) {
        g_clear_error(&icon_error);
        // Fallback: load the PNG bundled alongside the binary
        GdkPixbuf* icon_buf = gdk_pixbuf_new_from_file(png_path, &icon_error);
        if (icon_buf) {
          gtk_window_set_icon(window, icon_buf);
          g_object_unref(icon_buf);
        } else {
          g_clear_error(&icon_error);
        }
      }
    }
  }

  // Also set the default icon list so all windows (including secondary) inherit it
  gtk_window_set_default_icon_name("onyxcore");

  g_autoptr(FlDartProject) project = fl_dart_project_new();
  fl_dart_project_set_dart_entrypoint_arguments(
      project, self->dart_entrypoint_arguments);

  FlView* view = fl_view_new(project);
  self->main_view = view;
  GdkRGBA background_color;
  // Background defaults to black, override it here if necessary, e.g. #00000000
  // for transparent.
  gdk_rgba_parse(&background_color, "#000000");
  fl_view_set_background_color(view, &background_color);
  
  // Track events to capture the user_time for focus stealing prevention
  // We attach to the view directly for specific input events, as Flutter stops propagation to the window
  gtk_widget_add_events(GTK_WIDGET(view), GDK_BUTTON_PRESS_MASK | GDK_KEY_PRESS_MASK | GDK_TOUCH_MASK);
  g_signal_connect(view, "button-press-event", G_CALLBACK(on_app_input_event), NULL);
  g_signal_connect(view, "key-press-event", G_CALLBACK(on_app_input_event), NULL);
  g_signal_connect(view, "touch-event", G_CALLBACK(on_app_input_event), NULL);
  
  g_signal_connect(window, "focus-in-event", G_CALLBACK(on_main_window_focus_in), NULL);
  
  gtk_widget_show(GTK_WIDGET(view));
  gtk_container_add(GTK_CONTAINER(window), GTK_WIDGET(view));

  // Show the window when Flutter renders.
  // Requires the view to be realized so we can start rendering.
  g_signal_connect_swapped(view, "first-frame", G_CALLBACK(first_frame_cb),
                           self);
  gtk_widget_realize(GTK_WIDGET(view));

  fl_register_plugins(FL_PLUGIN_REGISTRY(view));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  FlMethodChannel* channel = fl_method_channel_new(
      fl_engine_get_binary_messenger(fl_view_get_engine(view)),
      "onyxcore/window_manager",
      FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, window_method_call_handler, self, nullptr);
  self->window_channel = channel; // Store globally for sending events to Dart

  gtk_widget_grab_focus(GTK_WIDGET(view));
}

// Implements GApplication::local_command_line.
static gboolean my_application_local_command_line(GApplication* application,
                                                  gchar*** arguments,
                                                  int* exit_status) {
  MyApplication* self = MY_APPLICATION(application);
  // Strip out the first argument as it is the binary name.
  self->dart_entrypoint_arguments = g_strdupv(*arguments + 1);

  g_autoptr(GError) error = nullptr;
  if (!g_application_register(application, nullptr, &error)) {
    g_warning("Failed to register: %s", error->message);
    *exit_status = 1;
    return TRUE;
  }

  g_application_activate(application);
  *exit_status = 0;

  return TRUE;
}

// Implements GApplication::startup.
static void my_application_startup(GApplication* application) {
  // MyApplication* self = MY_APPLICATION(object);

  // Perform any actions required at application startup.

  G_APPLICATION_CLASS(my_application_parent_class)->startup(application);
}

// Implements GApplication::shutdown.
static void my_application_shutdown(GApplication* application) {
  GList* windows = gtk_application_get_windows(GTK_APPLICATION(application));
  if (windows != nullptr && g_list_length(windows) > 0) {
    return;
  }
  G_APPLICATION_CLASS(my_application_parent_class)->shutdown(application);
}

// Implements GObject::dispose.
static void my_application_dispose(GObject* object) {
  MyApplication* self = MY_APPLICATION(object);
  g_clear_pointer(&self->dart_entrypoint_arguments, g_strfreev);
  G_OBJECT_CLASS(my_application_parent_class)->dispose(object);
}

static void my_application_class_init(MyApplicationClass* klass) {
  G_APPLICATION_CLASS(klass)->activate = my_application_activate;
  G_APPLICATION_CLASS(klass)->local_command_line =
      my_application_local_command_line;
  G_APPLICATION_CLASS(klass)->startup = my_application_startup;
  G_APPLICATION_CLASS(klass)->shutdown = my_application_shutdown;
  G_OBJECT_CLASS(klass)->dispose = my_application_dispose;
}

static void my_application_init(MyApplication* self) {}

MyApplication* my_application_new() {
  // Set the program name to the application ID, which helps various systems
  // like GTK and desktop environments map this running application to its
  // corresponding .desktop file. This ensures better integration by allowing
  // the application to be recognized beyond its binary name.
  g_set_prgname(APPLICATION_ID);

  return MY_APPLICATION(g_object_new(my_application_get_type(),
                                     "application-id", APPLICATION_ID, "flags",
                                     G_APPLICATION_NON_UNIQUE, nullptr));
}
