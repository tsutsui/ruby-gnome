/* -*- c-file-style: "ruby"; indent-tabs-mode: nil -*- */
/*
 *  Copyright (C) 2012  Ruby-GNOME2 Project Team
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
 *  MA  02110-1301  USA
 */

#include "rb-gobject-introspection.h"

#define RG_TARGET_NAMESPACE rb_cGIConstructorInfo
#define SELF(self) RVAL2GI_FUNCTION_INFO(self)

GType
gi_constructor_info_get_type(void)
{
    static GType type = 0;
    if (type == 0) {
	type = g_boxed_type_register_static("GIConstructorInfo",
                                            (GBoxedCopyFunc)g_base_info_ref,
                                            (GBoxedFreeFunc)g_base_info_unref);
    }
    return type;
}

static VALUE
rg_invoke(int argc, VALUE *argv, VALUE self)
{
    GIFunctionInfo *info;
    GICallableInfo *callable_info;
    VALUE receiver;
    GIArgument return_value;
    GITypeInfo return_value_info;
    GIBaseInfo *interface_info;
    GIInfoType interface_type;

    info = SELF(self);
    callable_info = (GICallableInfo *)info;

    /* TODO: check argc. */
    receiver = argv[0];
    rb_gi_function_info_invoke_raw(info, argc - 1, argv + 1, &return_value);
    g_callable_info_load_return_type(callable_info, &return_value_info);

    if (g_type_info_get_tag(&return_value_info) != GI_TYPE_TAG_INTERFACE) {
        rb_raise(rb_eRuntimeError, "TODO: returned value isn't interface");
    }
    interface_info = g_type_info_get_interface(&return_value_info);
    interface_type = g_base_info_get_type(interface_info);
    if (interface_type != GI_INFO_TYPE_OBJECT) {
        rb_raise(rb_eRuntimeError, "TODO: returned value isn't object");
    }
    g_object_ref_sink(return_value.v_pointer);
    G_INITIALIZE(receiver, return_value.v_pointer);

    return receiver;
}

void
rb_gi_constructor_info_init(VALUE rb_mGI, VALUE rb_cGIFunctionInfo)
{
    VALUE RG_TARGET_NAMESPACE;

    RG_TARGET_NAMESPACE =
	G_DEF_CLASS_WITH_PARENT(GI_TYPE_CONSTRUCTOR_INFO,
                                "ConstructorInfo", rb_mGI,
				rb_cGIFunctionInfo);

    RG_DEF_METHOD(invoke, -1);
}
