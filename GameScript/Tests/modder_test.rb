#----------------------------------------------------------------
#  modder_test.rb
#
#  Changelog:
#      Paulinchen  2026-11-07: Read the blocks of the modder pages of docs/ui in place of MODDER.md
#      Paulinchen  2026-11-06: Listed the animated color names as C# lists them now
#                            - Removed the checks of the old UI scan
#                            - Created
#
#----------------------------------------------------------------

# Covers the modder pages of docs/ui, those of the calls beyond the parts: every Ruby block of them
# runs in a booted game against FakeTree, one after another as the mods of one game session, the
# way a modder copies it into a mod. A block raises nothing and the framework logs no error for it,
# and every component it defines without a required param shows, opened by the test where the block
# leaves that to a command or a hotkey.

require_relative "game_lists_support"
require_relative "layer_support"
require_relative "equip_support"

# The modder pages, in the order their blocks run.
PAGES = %w[component mod options hotkeys settings hooks].map { |name| File.expand_path("../../docs/ui/#{name}.md", File.dirname(__FILE__)) }

# What a log line of the framework says when something a block did went wrong.
WRONG = /fail|refus|(?<!:)error|did you mean|takes no|is no |matches nothing|needs |would hide|cannot|not open/i

# Tells the Ruby blocks of the modder pages.
#
# @return [Array<Array>] Each block's place, such as "mod.md:42", and its code without the indent of
#   its fence.
def modder_blocks
  PAGES.map { |page| page_blocks(page) }.flatten(1)
end

# Tells the Ruby blocks of one page.
#
# @param page [String] The page's path.
# @return [Array<Array>] Each block's place and its code, see modder_blocks.
def page_blocks(page)
  lines = File.binread(page).force_encoding("UTF-8").split(/\r?\n/)
  blocks = []
  index = 0
  while index < lines.size
    indent = lines[index][/\A( *)```ruby\s*\z/, 1]
    if indent
      ending = (index + 1...lines.size).find { |place| lines[place] =~ /\A *```\s*\z/ }
      code = lines[index + 1...ending].map { |line| line.sub(/\A {0,#{indent.size}}/, "") }
      blocks << ["#{File.basename(page)}:#{index + 2}", code.join("\n") + "\n"]
      index = ending
    end
    index += 1
  end
  blocks
end

# Defines what the pages' blocks name of the game besides the framework's stand-ins: the game's
# menu, gold and map name windows, the map and the equip scene, the party's gold, its members' HP
# and MP, the map and the switches.
def define_modder_game
  [:Window_MenuCommand, :Window_Gold, :Window_MapName, :Scene_Map, :Scene_Equip, :Game_Party].each do |name|
    Object.send(:remove_const, name) if Object.const_defined?(name)
  end
  Object.class_eval <<-RUBY
    class Window_MenuCommand < Window_Command
      COMMANDS = [[:item, "Items"], [:equip, "Equip"], [:skill, "Skills"], [:status, "Status"], [:formation, "Formation"],
                  [:library, "Library"], [:config, "Config"], [:save, "Save"], [:game_end, "Game End"]]
      def initialize; super(0, 0); end
      def make_command_list; COMMANDS.each { |symbol, name| add_command(name, symbol) }; end
    end
    class Window_Gold < Window_Base; def initialize; super(0, 0, 160, 48); end; end
    class Window_MapName < Window_Base; def initialize; super(0, 0, 240, 48); end; end
    class Scene_Map < Scene_Base; def update; end; end
    class Scene_Equip < Scene_Base; def actor; $game_party.menu_actor; end; end
    class Game_Party; def gain_gold(amount); end; end
  RUBY
  equip_party
  def $game_party.gold; 500; end
  $game_party.members.each do |member|
    def member.hp; 900; end
    def member.mhp; 1200; end
    def member.mp; 40; end
    def member.mmp; 80; end
  end
  $game_map = Struct.new(:display_name, :map_id).new("Iliasburg", 1)
  $game_switches = Hash.new(false)
  $game_variables = Hash.new(0)
end

# Makes the DLL's side of the pages' game: the tree's, and the theme's and the notices' topics as
# far as the blocks reach them, the presets and color names a block adds known from then on.
#
# @param tree [FakeTree] The tree.
# @return [FakeBridge] The DLL's side.
def modder_dll(tree)
  fake = tree_dll(tree)
  added = []
  fake.answer("ui.theme.preset") { |request| added << request; nil }
  fake.answer("ui.theme.color") { |request| added << request; nil }
  fake.answer("ui.theme.names") do |_request|
    colors = added.select { |each| each.key?("value") || each.key?("moves") }
    presets = added.select { |each| each.key?("palette") || each.key?("from") }
    [["Monarch", "Legacy"] + presets.map { |each| each["name"] }, ["red", "yellow", "rainbow"] + colors.map { |each| each["name"] }]
  end
  fake.answer("ui.theme.pick") { |_name| ["Monarch", nil] }
  fake.answer("ui.theme.resolve") do |_name|
    plain = added.select { |each| each["value"].is_a?(Array) }
    { "name" => "Monarch", "game" => false, "palette" => { "back" => [36, 10, 14, 235], "text" => [255, 255, 255, 255], "primary" => [200, 160, 80, 255] },
      "colors" => Hash[plain.map { |each| [each["name"], each["value"] + [255]] }], "typography" => { "body1" => 18 }, "spacing" => 4, "rows" => [24, 20] }
  end
  fake.answer("ui.theme.look") { |request| { "fill" => request[2], "edge" => nil, "text" => [0, 0, 0, 255], "lit" => request[2] && { "name" => request[2], "lift" => 5 }, "focus" => "title" } }
  fake.answer("notices.toast") { |_toast| nil }
  fake
end

# Defines the game's options with an empty list of the mods' rows.
def define_options_game
  Object.send(:remove_const, :NWConst) if Object.const_defined?(:NWConst)
  Object.class_eval("module NWConst; module Config; CONTENTS = [{ :key => :return }]; DATA = {}; DATA_TEXT = {}; DEFAULT = {}; MOD_CONTENTS = [{ :key => :return }]; end; end")
end

# Tells the component classes of the UI layer defined so far.
#
# @return [Array<Class>] The classes.
def component_classes
  ObjectSpace.each_object(Class).select { |klass| klass < Mod_Framework::UI::Component }
end

# Tells whether a component class needs a param its caller must give.
#
# @param klass [Class] The class.
# @return [Boolean] Whether it does.
def needs_params?(klass)
  klass.params.any? { |_name, param| !param[:handler] && !param[:content] && param[:default].equal?(Mod_Framework::UI::Component::NONE) && param[:block].nil? }
end

GC.disable
in_game_folder do
  tree = FakeTree.new
  boot_tree(modder_dll(tree), :game => lambda { define_game_lists; define_options_game }) do
    define_modder_game
    frame
    raised = []
    wrong = []
    unseen = []
    blocks = modder_blocks
    blocks.each do |place, code|
      known = component_classes
      logged = $logged.size
      begin
        load_mod("Patch/Modder_#{place.tr('.:', '__')}.rb", code)
        frame
        (component_classes - known).each do |klass|
          next if needs_params?(klass) || ObjectSpace.each_object(klass).any?

          Mod_Framework::UI::Engine::Layer.start(:any, klass, {}, nil)
        end
        frame
        Graphics.update
      rescue Exception => e
        raised << "#{place}: #{e.class}: #{e.message}"
      end
      wrong.concat($logged[logged..-1].grep(WRONG).map { |text| "#{place}: #{text}" })
      unseen.concat((component_classes - known).reject { |klass| needs_params?(klass) || ObjectSpace.each_object(klass).any? }.map { |klass| "#{place}: #{klass}" })
    end

    check("the modder pages have their Ruby blocks", blocks.size > 10, true)

    check("every block of the modder pages runs as a mod without raising", raised, [])
    check("the framework logs nothing wrong for a block of the modder pages", wrong, [])
    check("every component a block defines without a required param shows", unseen, [])
  end
end
