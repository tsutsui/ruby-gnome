# Copyright (C) 2015-2022  Ruby-GNOME Project Team
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

class TestGtkLabel < Test::Unit::TestCase
  include GtkTestUtils

  sub_test_case ".new" do
    test "use_underline: true" do
      label = Gtk::Label.new("_Hello", use_underline: true)
      assert_equal("H", [label.mnemonic_keyval].pack("U"))
    end
  end

  sub_test_case "instance methods" do
    sub_test_case "set_markup" do
      def setup
        @label = Gtk::Label.new
      end

      test "use_underline: true" do
        @label.set_markup("_Hello", use_underline: true)
        assert_equal("H", [@label.mnemonic_keyval].pack("U"))
      end
    end
  end
end