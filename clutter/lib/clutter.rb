# Copyright (C) 2012-2021  Ruby-GNOME Project Team
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

require "gobject-introspection"
require "cairo-gobject"
require "pango"

module Clutter
  LOG_DOMAIN = "Clutter"
  GLib::Log.set_log_domain(LOG_DOMAIN)

  class << self
    def const_missing(name)
      init
      if const_defined?(name)
        const_get(name)
      else
        super
      end
    end

    @@init_hooks = []
    def init(argv=[])
      class << self
        remove_method(:init)
        remove_method(:const_missing)
      end
      loader = Loader.new(self, argv)
      loader.load
      require "clutter/actor"
      require "clutter/actor-iter"
      require "clutter/animatable"
      require "clutter/brightness-contrast-effect"
      require "clutter/cairo"
      require "clutter/clutter"
      require "clutter/color"
      require "clutter/event"
      require "clutter/point"
      require "clutter/text"
      require "clutter/text-buffer"
      require "clutter/threads"
      require "clutter/version"

      @@init_hooks.each do |hook|
        hook.call
      end
    end

    def on_init(&block)
      @@init_hooks << block
    end
  end

  class InitError < StandardError
  end

  class Loader < GObjectIntrospection::Loader
    NAMESPACE = "Clutter"

    def initialize(base_module, init_arguments)
      super(base_module)
      @init_arguments = init_arguments
      @key_constants = {}
      @other_constant_infos = []
      @event_infos = []
    end

    def load
      super(NAMESPACE)
    end

    private
    def pre_load(repository, namespace)
      init = repository.find(namespace, "init")
      arguments = [
        [$0] + @init_arguments,
      ]
      error, returned_arguments = init.invoke(arguments)
      @init_arguments.replace(returned_arguments[1..-1])
      if error.to_i <= 0
        raise InitError, "failed to initialize Clutter: #{error.name}"
      end
      @keys_module = define_methods_module(:Keys)
      @threads_module = define_methods_module(:Threads)
      @feature_module = define_methods_module(:Feature)
      @version_module = define_methods_module(:Version)
    end

    def post_load(repository, namespace)
      post_methods_module(@keys_module)
      post_methods_module(@threads_module)
      post_methods_module(@feature_module)
      post_methods_module(@version_module)
      @other_constant_infos.each do |constant_info|
        name = constant_info.name
        next if @key_constants.has_key?("KEY_#{name}")
        @base_module.const_set(name, constant_info.value)
      end
      load_events
    end

    def load_events
      @event_infos.each do |event_info|
        define_struct(event_info, :parent => Event)
      end
      event_map = {
        EventType::KEY_PRESS      => KeyEvent,
        EventType::KEY_RELEASE    => KeyEvent,
        EventType::MOTION         => MotionEvent,
        EventType::ENTER          => CrossingEvent,
        EventType::LEAVE          => CrossingEvent,
        EventType::BUTTON_PRESS   => ButtonEvent,
        EventType::BUTTON_RELEASE => ButtonEvent,
        EventType::SCROLL         => ScrollEvent,
        EventType::STAGE_STATE    => StageStateEvent,
        EventType::TOUCH_UPDATE   => TouchEvent,
        EventType::TOUCH_END      => TouchEvent,
        EventType::TOUCH_CANCEL   => TouchEvent,
      }
      self.class.register_boxed_class_converter(Event.gtype) do |event|
        event_map[event.type] || Event
      end
    end

    def load_struct_info(info)
      if info.name.end_with?("Event")
        @event_infos << info
      else
        super
      end
    end

    def load_function_info(info)
      name = info.name
      case name
      when "init"
        # ignore
      when /\Athreads_/
        define_module_function(@threads_module, $POSTMATCH, info)
      when /\Afeature_/
        method_name = rubyish_method_name(info, :prefix => "feature_")
        case method_name
        when "available"
          method_name = "#{method_name}?"
        end
        define_module_function(@feature_module, method_name, info)
      else
        super
      end
    end

    def load_constant_info(info)
      case info.name
      when /\AKEY_/
        @key_constants[info.name] = true
        @keys_module.const_set(info.name, info.value)
      when /_VERSION\z/
        @version_module.const_set($PREMATCH, info.value)
      else
        @other_constant_infos << info
      end
    end
  end
end
