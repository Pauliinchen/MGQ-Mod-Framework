#----------------------------------------------------------------
#  game_menus.rbx
#
#  Changelog:
#      Paulinchen  2026-11-09: Forgot the game's pictures down to a few as memory runs low
#                            - Kept the faces of the menu's party list in the game's cache
#                            - Kept the cursor of a long item list on its item as the list scrolls
#      Paulinchen  2026-11-07: Named Options > Mods in the log texts
#      Paulinchen  2026-11-05: Created
#
#----------------------------------------------------------------

module Mod_Framework
  module UI
    module Engine
      # Takes the lag out of the game's own menus, each fix with a row of Options > Mods that turns
      # it off: the gear previews of the equip screen and the shop, the cache of the game's
      # pictures, long item lists, and the menu's party list.
      module GameMenus
        # What a row reads while its fix works.
        ON = "On"

        # What a row reads while the game does it its own way.
        OFF = "Off"

        # Each fix: its setting, its row's key, name and help.
        FIXES = {
          :previews => ["game_quick_previews", :mf_game_quick_previews, "Quick Gear Previews",
                        "On: the game's equip screen and shop work out a character's stats with an item\n" \
                        "without the full refresh of a copy, where the refresh would change nothing.\n" \
                        "Off: every preview refreshes its copy, as the game does."],
          :pictures => ["game_picture_cache", :mf_game_picture_cache, "Picture Cache",
                        "On: past 100 pictures the game forgets the ones it used least long ago.\n" \
                        "Off: the game forgets all of them and stops for a garbage collection, as it does."],
          :lists => ["game_long_lists", :mf_game_long_lists, "Long Item Lists",
                     "On: a long list of items draws only the rows in view, and the rest as it scrolls.\n" \
                     "Off: the list draws every row onto one tall picture, as the game does."],
          :party => ["game_quick_party", :mf_game_quick_party, "Quick Party List",
                     "On: the menu's party list keeps its faces once drawn.\n" \
                     "Off: the list reads every face from its file anew, as the game does."]
        }

        extend Logging

        # What starts this script's lines in the log.
        LOG_TAG = "game menus"

        # Each fix's state by name, read from the settings the first time.
        @on = {}

        # Tells whether a fix works.
        #
        # @param fix [Symbol] The fix, see FIXES.
        # @return [Boolean] Whether it does; on until the player turns it off.
        def self.on?(fix)
          @on[fix] = Settings.setting(FIXES[fix][0]).to_s != "0" unless @on.key?(fix)
          @on[fix]
        end

        # Turns a fix on or off and keeps it in the settings.
        #
        # @param fix [Symbol] The fix.
        # @param on [Boolean] Whether it works.
        def self.turn(fix, on)
          @on[fix] = on
          kept = Settings.store(FIXES[fix][0], on ? 1 : 0)
          log("#{FIXES[fix][2]} is #{on ? 'on' : 'off'}#{kept ? '' : ', not kept'}")
        end

        # Offers each fix as a row of Options > Mods.
        def self.add_options
          FIXES.each do |fix, (_setting, key, name, help)|
            added = Options.keep(key, Options::GROUP + name, help, lambda { [ON, OFF] },
                                 lambda { on?(fix) ? ON : OFF }, lambda { |value| turn(fix, value == ON) })
            log("no #{name} row in Options > Mods, see the options lines") unless added
          end
        end

        # Puts each fix into the game, where the game has what it fixes.
        def self.install
          Previews.install
          PictureCache.install
          LongLists.install
          PartyFaces.install
          add_options
        end

        # The gear previews of the game's equip screen and shop, which put an item on a copy of a
        # character with force_change_equip and read the copy's stats: the copy wears the item
        # without the game's refresh where the refresh would leave it as it is, and works its
        # features out once for every stat read.
        module Previews
          # What the copy keeps until it changes again.
          module KeptFeatures
            # Tells the objects whose features the copy has, worked out once.
            #
            # @return [Object] What the game's feature_objects answers.
            def feature_objects
              @__mf_preview_features ||= super
            end

            # Forgets the features worked out, then refreshes as the game does.
            def refresh
              @__mf_preview_features = nil
              super
            end

            # Forgets the features worked out, then changes the equip as the game does.
            #
            # @param slot [Integer] The slot.
            # @param item [RPG::EquipItem, nil] The item.
            def force_change_equip(slot, item)
              @__mf_preview_features = nil
              super
            end
          end

          # Puts the fix on the game's force_change_equip.
          def self.install
            return unless defined?(::Game_Actor) && ::Game_Actor.method_defined?(:force_change_equip)

            Hooks.around(::Game_Actor, :force_change_equip, "Mod Framework quick previews") do |actor, args, original|
              Mod_Framework::UI::Engine::GameMenus::Previews.wear(actor, *args) ? nil : original.call
            end
          end

          # Puts an item into a slot of a copy of a character without the game's refresh, where the
          # refresh would leave the copy as it is.
          #
          # @param actor [Game_Actor] The character the game changes.
          # @param slot [Integer] The slot.
          # @param item [RPG::EquipItem, nil] The item.
          # @return [Boolean] Whether it did; false leaves the change to the game.
          def self.wear(actor, slot, item)
            return false unless GameMenus.on?(:previews) && copy?(actor)

            slots = actor.instance_variable_get(:@equips)
            place = slots.is_a?(Array) ? slots[slot] : nil
            return false unless place.respond_to?(:object=)

            worn = place.object
            place.object = item
            actor.extend(KeptFeatures) unless actor.is_a?(KeptFeatures)
            actor.instance_variable_set(:@__mf_preview_features, nil)
            ::CacheActorFeatures.init_actor(actor) if defined?(::CacheActorFeatures) && ::CacheActorFeatures.respond_to?(:init_actor)
            return true if GearTrial.refresh_keeps?(actor)

            place.object = worn
            false
          end

          # Tells whether a character is a copy the game made, not one of its own characters.
          #
          # @param actor [Game_Actor] The character.
          # @return [Boolean] Whether it is a copy.
          def self.copy?(actor)
            $game_actors && actor.respond_to?(:id) && !$game_actors[actor.id].equal?(actor)
          end
        end

        # The game's cache of pictures, which Paradox empties whole once it holds more than 100 and
        # then stops the game for a garbage collection: it forgets the pictures used least long ago
        # instead, and collects only once the pictures it forgot take more than FORGOTTEN_BYTES.
        module PictureCache
          # The most pictures the cache keeps, as Paradox keeps.
          MOST = 100

          # The pictures it keeps after forgetting some.
          KEPT = 80

          # The bytes of forgotten pictures that start a garbage collection, which frees them.
          FORGOTTEN_BYTES = 64 * 1024 * 1024

          extend Logging

          # What starts this script's lines in the log.
          LOG_TAG = "picture cache"

          # The bytes of the pictures forgotten since the last collection, and GC.count then.
          @forgotten = 0
          @collections = nil

          # Puts the fix on Paradox's cache.
          def self.install
            return unless defined?(::Cache) && ::Cache.respond_to?(:check_filesize) && ::Cache.respond_to?(:normal_bitmap)

            owner = ::Cache.singleton_class
            Hooks.around(owner, :check_filesize, "Mod Framework picture cache") do |cache, _args, original|
              GameMenus.on?(:pictures) ? Mod_Framework::UI::Engine::GameMenus::PictureCache.trim(cache) : original.call
            end
            Hooks.before(owner, :normal_bitmap, "Mod Framework picture cache") { |path| Mod_Framework::UI::Engine::GameMenus::PictureCache.used(self, path) }
            return unless owner.method_defined?(:hue_changed_bitmap)

            Hooks.before(owner, :hue_changed_bitmap, "Mod Framework picture cache") { |path, hue| Mod_Framework::UI::Engine::GameMenus::PictureCache.used(self, [path, hue]) }
          end

          # Marks a picture used, so it is forgotten last.
          #
          # @param cache [Module] The game's Cache.
          # @param key [Object] The picture's key in the cache.
          def self.used(cache, key)
            pictures = cache.instance_variable_get(:@cache)
            return unless GameMenus.on?(:pictures) && pictures.is_a?(Hash) && pictures.key?(key)

            pictures[key] = pictures.delete(key)
          end

          # Forgets the pictures used least long ago once the cache holds more than MOST.
          #
          # @param cache [Module] The game's Cache.
          def self.trim(cache)
            pictures = cache.instance_variable_get(:@cache)
            return unless pictures.is_a?(Hash) && pictures.size > MOST

            @forgotten = 0 if @collections != GC.count
            dropped = pictures.keys.first(pictures.size - KEPT)
            dropped.each do |key|
              picture = pictures.delete(key)
              @forgotten += picture.width * picture.height * 4 if picture && !picture.disposed?
            end
            collect = @forgotten > FORGOTTEN_BYTES
            log(format("forgot the %d pictures used least long ago, %.0f MB forgotten since the last collection%s",
                       dropped.size, @forgotten / 1_048_576.0, collect ? ", collecting" : ""))
            GC.start if collect
            @forgotten = 0 if collect
            @collections = GC.count
          end

          # Forgets the pictures kept least long ago down to a count, as memory runs low; a picture
          # forgotten keeps showing where it shows, and the collector frees it once nothing does.
          #
          # @param left [Integer] How many it keeps.
          # @return [Integer] How many it forgot.
          def self.forget(left)
            pictures = defined?(::Cache) ? ::Cache.instance_variable_get(:@cache) : nil
            return 0 unless pictures.is_a?(Hash) && pictures.size > left

            dropped = pictures.keys.first(pictures.size - left)
            dropped.each { |key| pictures.delete(key) }
            dropped.size
          end
        end

        # Long item lists, which the game draws onto one picture as tall as all their rows, which
        # Paradox makes through a picture file once it is large: a list that holds more than TALL
        # pages has a picture of the rows in view, a row more on either side so the window's arrows
        # show as before, and draws them anew as it scrolls.
        module LongLists
          # The pages a list must hold before it draws only the rows in view.
          TALL = 3

          # The methods the fix takes over; a window whose class has its own of one stays the game's.
          OWN = [:contents_height, :top_row, :top_row=, :item_rect, :draw_all_items, :redraw_item, :oy=]

          # What a long item list draws with while it shows only the rows in view.
          module Rows
            # Tells the height of its picture: the rows from the one before the first in view to the
            # one after the last, while it draws only those.
            #
            # @return [Integer] The pixels.
            def contents_height
              rows = LongLists.rows?(self)
              rows_mode(rows) unless rows == (@__mf_rows ? true : false)
              return super unless @__mf_rows

              (rows_last - rows_base + 1) * item_height
            end

            # Tells the first row in view.
            #
            # @return [Integer] The row.
            def top_row
              @__mf_rows ? (@__mf_top || 0) : super
            end

            # Scrolls to a first row in view, drawing the rows anew once it changed.
            #
            # @param row [Integer] The row.
            def top_row=(row)
              return super unless @__mf_rows

              row = [[row, row_max - 1].min, 0].max
              return if row == top_row

              first = picture_first
              @__mf_top = row
              follow_rows(first)
              redraw_rows
            end

            # Scrolls as the game sets the picture's offset, such as to the top as a list changes.
            #
            # @param value [Integer] The offset in pixels.
            def oy=(value)
              return super unless @__mf_rows

              self.top_row = value.to_i / [item_height, 1].max
            end

            # Tells where an item lies on its picture.
            #
            # @param index [Integer] The item.
            # @return [Rect] Its place.
            def item_rect(index)
              rect = super
              rect.y -= rows_base * item_height if @__mf_rows
              rect
            end

            # Draws the items of the rows its picture holds, marked drawn where Paradox draws a list
            # page by page as it scrolls, so it draws none of them twice.
            def draw_all_items
              return super unless @__mf_rows

              drawn = @draw.is_a?(Array) ? @draw = [] : nil
              first = rows_base * col_max
              last = [(rows_last + 1) * col_max, item_max].min
              (first...last).each do |index|
                draw_item(index)
                drawn[index] = true if drawn
              end
              shown_offset((top_row - rows_base) * item_height)
            end

            # Draws an item anew where its picture holds it.
            #
            # @param index [Integer] The item.
            def redraw_item(index)
              return super unless @__mf_rows

              row = index / col_max
              super if row >= rows_base && row <= rows_last
            end

            private

            # Tells the first row its picture holds: the one before the first in view.
            #
            # @return [Integer] The row.
            def rows_base
              [top_row - 1, 0].max
            end

            # Tells the first row its picture holds, the first of the list while it holds every row.
            #
            # @return [Integer] The row.
            def picture_first
              @__mf_rows ? rows_base : 0
            end

            # Moves the cursor with its item after the picture's first row moved, as the game's
            # scrolling of the picture moves it; the game's update_cursor would scroll again.
            #
            # @param first [Integer] The picture's first row before.
            def follow_rows(first)
              moved = (picture_first - first) * item_height
              cursor_rect.y -= moved unless moved == 0
            end

            # Tells the last row its picture holds: the one after the last in view.
            #
            # @return [Integer] The row.
            def rows_last
              [top_row + page_row_max, row_max - 1].min
            end

            # Draws the rows its picture holds anew, at the offset that puts the first in view at
            # the window's top.
            def redraw_rows
              height = (rows_last - rows_base + 1) * item_height
              height == contents.height ? contents.clear : create_contents
              draw_all_items
            end

            # Draws only the rows in view from now on, or every row again, keeping the first row in
            # view.
            #
            # @param rows [Boolean] Whether it draws only the rows in view.
            def rows_mode(rows)
              first = picture_first
              if rows
                @__mf_top = [[oy / [item_height, 1].max, row_max - 1].min, 0].max
              else
                shown_offset((@__mf_top || 0) * item_height)
              end
              @__mf_rows = rows
              follow_rows(first)
            end

            # Sets the offset its picture shows from, past the scrolling the fix takes over.
            #
            # @param value [Integer] The offset in pixels.
            def shown_offset(value)
              ::Window.instance_method(:oy=).bind(self).call(value)
            end
          end

          # Puts the fix into the game's item lists.
          def self.install
            return unless defined?(::Window_ItemList)

            ::Window_ItemList.send(:include, Rows)
          end

          # Tells whether a window draws only the rows in view: the fix is on, the window's class
          # has none of the methods the fix takes over of its own, and its list holds more than TALL
          # pages.
          #
          # @param window [Window_Selectable] The window.
          # @return [Boolean] Whether it does.
          def self.rows?(window)
            return false unless GameMenus.on?(:lists) && own?(window.class)

            window.row_max > TALL * [window.page_row_max, 1].max
          end

          # Tells whether a class of windows leaves every method the fix takes over to it.
          #
          # @param klass [Class] The class.
          # @return [Boolean] Whether it does.
          def self.own?(klass)
            (@own ||= {}).fetch(klass) { @own[klass] = OWN.all? { |name| klass.instance_method(name).owner == Rows } }
          end
        end

        # The faces of the menu's party list, which Paradox's draw_face_hue disposes in the game's
        # cache once drawn, so each opening of the menu reads every face from its file again: the
        # list leaves them in the cache, whose limit of pictures keeps them bounded.
        module PartyFaces
          # What the menu's party list draws its faces with.
          module Kept
            # Draws a face as Paradox does, leaving its picture in the game's cache.
            #
            # @param face_name [String] The face sheet's file.
            # @param face_index [Integer] The face on the sheet.
            # @param face_hue [Integer] The hue the sheet is shifted by.
            # @param x [Integer] The face's left edge.
            # @param y [Integer] The face's top edge.
            # @param enabled [Boolean] Whether it draws opaque.
            def draw_face_hue(face_name, face_index, face_hue, x, y, enabled = true)
              return super unless GameMenus.on?(:party)

              rect = ::Rect.new(face_index % 4 * 96, face_index / 4 * 96, 96, 96)
              contents.blt(x, y, ::Cache.face(face_name, face_hue), rect, enabled ? 255 : translucent_alpha)
            end
          end

          # Puts the fix into the menu's party list, where the game draws faces with Paradox's
          # draw_face_hue.
          def self.install
            return unless defined?(::Window_MenuStatus)
            return unless ::Window_MenuStatus.method_defined?(:draw_face_hue) || ::Window_MenuStatus.private_method_defined?(:draw_face_hue)

            ::Window_MenuStatus.send(:include, Kept)
          end
        end
      end

      # Once the game runs, the fixes of its menus go in.
      Run.on_start("game menus", :dll => true) { Mod_Framework::UI::Engine::GameMenus.install }
    end
  end
end
