# Copyright (C) 2013-2021  Ruby-GNOME Project Team
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA

module Gdk
  class Loader < GObjectIntrospection::Loader
    def load
      self.version = "3.0"
      super("Gdk")
    end

    private
    def event_class
      @event_class ||= @base_module.const_get(:Event)
    end

    def pre_load(repository, namespace)
      setup_pending_constants
      setup_pending_rectangle_functions
      define_keyval_module
      define_selection_module
      define_event_singleton_methods_module
      define_event_motion_methods_module
      define_window_methods_module
      define_cairo_context_methods_module
      define_cairo_surface_methods_module
      require_pre_libraries
    end

    def define_keyval_module
      @keyval_module = Module.new
      @base_module.const_set(:Keyval, @keyval_module)
      @keyval_module.const_set(:INVOKERS, {})
    end

    def post_keyval_module
      Ractor.make_shareable(@keyval_module::INVOKERS) if defined?(Ractor)
    end

    def define_selection_module
      @selection_module = Module.new
      @base_module.const_set(:Selection, @selection_module)
    end

    def define_event_singleton_methods_module
      @event_singleton_methods_module = Module.new
      @base_module.const_set(:EventSingletonMethods,
                             @event_singleton_methods_module)
      @event_singleton_methods_module.const_set(:INVOKERS, {})
    end

    def apply_event_singleton_methods
      event_class = @base_module.const_get(:Event)
      event_class.extend(@event_singleton_methods_module)
      if defined?(Ractor)
        Ractor.make_shareable(@event_singleton_methods_module::INVOKERS)
      end
    end

    def define_event_motion_methods_module
      @event_motion_methods_module = Module.new
      @base_module.const_set(:EventMotionMethods, @event_motion_methods_module)
      @event_motion_methods_module.const_set(:INVOKERS, {})
    end

    def apply_event_motion_methods
      event_motion_class = @base_module.const_get(:EventMotion)
      event_motion_class.include(@event_motion_methods_module)
      if defined?(Ractor)
        Ractor.make_shareable(@event_motion_methods_module::INVOKERS)
      end
    end

    def define_window_methods_module
      @window_methods_module = Module.new
      @base_module.const_set(:WindowMethods, @window_methods_module)
      @window_methods_module.const_set(:INVOKERS, {})
    end

    def apply_window_methods
      window_class = @base_module.const_get(:Window)
      window_class.include(@window_methods_module)
      if defined?(Ractor)
        Ractor.make_shareable(@window_methods_module::INVOKERS)
      end
    end

    def define_cairo_context_methods_module
      @cairo_context_methods_module = Module.new
      @base_module.const_set(:CairoContextMethods, @cairo_context_methods_module)
      @cairo_context_methods_module.const_set(:INVOKERS, {})
    end

    def apply_cairo_context_methods
      Cairo::Context.include(@cairo_context_methods_module)
      if defined?(Ractor)
        Ractor.make_shareable(@cairo_context_methods_module::INVOKERS)
      end
    end

    def define_cairo_surface_methods_module
      @cairo_surface_methods_module = Module.new
      @base_module.const_set(:CairoSurfaceMethods, @cairo_surface_methods_module)
      @cairo_surface_methods_module.const_set(:INVOKERS, {})
    end

    def apply_cairo_surface_methods
      Cairo::Surface.include(@cairo_surface_methods_module)
      if defined?(Ractor)
        Ractor.make_shareable(@cairo_surface_methods_module::INVOKERS)
      end
    end

    def require_pre_libraries
      require "gdk3/event-readers"
    end

    def post_load(repository, namespace)
      apply_pending_constants
      apply_pending_rectangle_functions
      post_keyval_module
      apply_event_singleton_methods
      apply_event_motion_methods
      apply_window_methods
      apply_cairo_context_methods
      apply_cairo_surface_methods
      require_post_libraries
      convert_event_classes
      define_selection_constants
    end

    def setup_pending_constants
      @pending_constants = []
    end

    def apply_pending_constants
      @pending_constants.each do |info|
        case info.name
        when /\AEVENT_/
          event_class.const_set($POSTMATCH, info.value)
        end
      end
    end

    def setup_pending_rectangle_functions
      @pending_rectangle_get_type_function = nil
      @pending_rectangle_functions = []
    end

    def apply_pending_rectangle_functions
      get_type_info = @pending_rectangle_get_type_function
      if get_type_info
        rectangle_class = load_cairo_rectangle_int
        gtype = get_type_info.invoke([])
        self.class.register_boxed_class_converter(gtype) do |rectangle|
          rectangle_class
        end
      else
        rectangle_class = @base_module.const_get(:Rectangle)
      end

      @pending_rectangle_functions.each do |info|
        name = rubyish_method_name(info, :prefix => "rectangle_")
        define_method(info, rectangle_class, name)
      end
    end

    def load_cairo_rectangle_int
      info = find_cairo_rectangle_int_info
      klass = self.class.define_class(info.gtype,
                                      "Rectangle",
                                      @base_module,
                                      :size => info.size)
      load_fields(info, klass)
      load_methods(info, klass)
      klass
    end

    def find_cairo_rectangle_int_info
      repository = GObjectIntrospection::Repository.default
      repository.each("cairo") do |info|
        if info.name == "RectangleInt"
          return info
        end
      end
      nil
    end

    def require_post_libraries
      require "gdk3/atom"
      require "gdk3/color"
      require "gdk3/cursor"
      require "gdk3/event"
      require "gdk3/rectangle"
      require "gdk3/rgba"
      require "gdk3/screen"
      require "gdk3/window"
      require "gdk3/window-attr"

      require "gdk3/cairo"

      require "gdk3/deprecated"
    end

    def convert_event_classes
      event_map = {
        EventType::EXPOSE              => EventExpose,
        EventType::MOTION_NOTIFY       => EventMotion,
        EventType::BUTTON_PRESS        => EventButton,
        EventType::BUTTON2_PRESS       => EventButton,
        EventType::BUTTON3_PRESS       => EventButton,
        EventType::BUTTON_RELEASE      => EventButton,
        EventType::KEY_PRESS           => EventKey,
        EventType::KEY_RELEASE         => EventKey,
        EventType::ENTER_NOTIFY        => EventCrossing,
        EventType::LEAVE_NOTIFY        => EventCrossing,
        EventType::FOCUS_CHANGE        => EventFocus,
        EventType::CONFIGURE           => EventConfigure,
        EventType::PROPERTY_NOTIFY     => EventProperty,
        EventType::SELECTION_CLEAR     => EventSelection,
        EventType::SELECTION_REQUEST   => EventSelection,
        EventType::SELECTION_NOTIFY    => EventSelection,
        EventType::PROXIMITY_IN        => EventProximity,
        EventType::PROXIMITY_OUT       => EventProximity,
        EventType::DRAG_ENTER          => EventDND,
        EventType::DRAG_LEAVE          => EventDND,
        EventType::DRAG_MOTION         => EventDND,
        EventType::DRAG_STATUS         => EventDND,
        EventType::DROP_START          => EventDND,
        EventType::DROP_FINISHED       => EventDND,
        EventType::VISIBILITY_NOTIFY   => EventVisibility,
        EventType::SCROLL              => EventScroll,
        EventType::WINDOW_STATE        => EventWindowState,
        EventType::SETTING             => EventSetting,
        EventType::OWNER_CHANGE        => EventOwnerChange,
        EventType::GRAB_BROKEN         => EventGrabBroken,
        EventType::DAMAGE              => EventExpose,
        EventType::TOUCH_BEGIN         => EventTouch,
        EventType::TOUCH_UPDATE        => EventTouch,
        EventType::TOUCH_END           => EventTouch,
        EventType::TOUCH_CANCEL        => EventTouch,
      }
      self.class.register_boxed_class_converter(Event.gtype) do |event|
        event_map[event.type] || Event
      end
    end

    def define_selection_constants
      selections = {
        "PRIMARY"         => "PRIMARY",
        "SECONDARY"       => "SECONDARY",
        "CLIPBOARD"       => "CLIPBOARD",
        "TARGET_BITMAP"   => "BITMAP",
        "TARGET_COLORMAP" => "COLORMAP",
        "TARGET_DRAWABLE" => "DRAWABLE",
        "TARGET_PIXMAP"   => "PIXMAP",
        "TARGET_STRING"   => "STRING",
        "TYPE_ATOM"       => "ATOM",
        "TYPE_BITMAP"     => "BITMAP",
        "TYPE_COLORMAP"   => "COLORMAP",
        "TYPE_DRAWABLE"   => "DRAWABLE",
        "TYPE_INTEGER"    => "INTEGER",
        "TYPE_PIXMAP"     => "PIXMAP",
        "TYPE_WINDOW"     => "WINDOW",
        "TYPE_STRING"     => "STRING",
      }
      selections.each do |key, value|
        @selection_module.const_set(key, Gdk::Atom.intern(value))
      end
    end

    def load_function_info(info)
      name = info.name
      case name
      when "rectangle_get_type"
        @pending_rectangle_get_type_function = info
      when /\Arectangle_/
        @pending_rectangle_functions << info
      when "init", /_get_type\z/
        # ignore
      when /\Apixbuf_/
        target_class = nil
        case $POSTMATCH
        when "get_from_window"
          target_class = @window_methods_module
        when "get_from_surface"
          target_class = @cairo_surface_methods_module
        end
        if target_class
          define_method(info, target_class, "to_pixbuf")
        else
          super
        end
      when /\Aevent_/
        name = $POSTMATCH
        case name
        when "request_motions"
          define_method(info, @event_motion_methods_module, "request")
        else
          # ignore because moved to Gdk::Event
        end
      when /\Aevents_/
        method_name = rubyish_method_name(info, :prefix => "events_")
        define_module_function(@event_singleton_methods_module,
                               method_name,
                               info)
      when /\Acairo_/
        name = $POSTMATCH
        case name
        when "create"
          define_method(info, @window_methods_module, "create_cairo_context")
        when "set_source_color"
          define_method(info,
                        @cairo_context_methods_module,
                        "set_source_gdk_color")
        when "set_source_rgba"
          define_method(info,
                        @cairo_context_methods_module,
                        "set_source_gdk_rgba")
        when "rectangle"
          define_method(info,
                        @cairo_context_methods_module,
                        "gdk_rectangle")
        when "region_create_from_surface"
          # TODO
        when "surface_create_from_pixbuf"
          # TODO
        else
          define_method(info, @cairo_context_methods_module, name)
        end
      when /\Akeyval_/
        name = rubyish_method_name(info, :prefix => "keyval_")
        case name
        when "name"
          name = "to_name"
        end
        define_module_function(@keyval_module, name, info)
      else
        super
      end
    end

    def load_struct_info(info)
      return if info.gtype_struct?

      case info.name
      when /\AEvent/
        name = rubyish_class_name(info)
        klass = Class.new(event_class)
        @base_module.const_set(name, klass)
        load_fields(info, klass)
        load_methods(info, klass)
      else
        define_struct(info)
      end
    end

    def define_enum(info)
      case info.name
      when "EventType"
        self.class.register_constant_rename_map("2BUTTON_PRESS",
                                                "BUTTON2_PRESS")
        self.class.register_constant_rename_map("3BUTTON_PRESS",
                                                "BUTTON3_PRESS")
        super
      else
        super
      end
    end

    def load_constant_info(info)
      case info.name
      when /\AEVENT_/
        @pending_constants << info
      when /\AKEY_/
        @keyval_module.const_set(info.name, info.value)
      else
        super
      end
    end

    def load_field(info, i, field_info, klass)
      return super unless klass.name.start_with?("Gdk::Event")

      field_name = field_info.name
      if klass.name == "Gdk::Event"
        super if field_name == "type"
        return
      end

      case field_name
      when "window", "direction"
        super(info, i, field_info, klass, :readable => false)
      when "axes"
        klass.__send__(:prepend, EventAxisReader)
      when "button"
        klass.__send__(:prepend, EventButtonReader)
      when "state"
        case klass.name
        when "Gdk::EventProperty", "Gdk::EventVisibility"
          super
        else
          klass.__send__(:prepend, EventStateReader)
        end
      when "x"
        klass.__send__(:prepend, EventCoordsReader)
      when "x_root"
        klass.__send__(:prepend, EventRootCoordsReader)
      else
        unless klass.method_defined?(field_name)
          super
        end
      end
    end

    def may_be_cached?(constructor_info, klass)
      case klass.name
      when "Gdk::Cursor"
        case constructor_info.name
        when "new_from_name", "new_for_display"
          true
          # false
        else
          false
        end
      else
        false
      end
    end
  end
end
