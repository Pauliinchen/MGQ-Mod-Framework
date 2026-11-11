#----------------------------------------------------------------
#  boot.rbx
#
#  Changelog:
#      Paulinchen  2026-11-11: Noted the scripts of Patch as the game's loader listed them, before the waiting updates moved in
#      Paulinchen  2026-11-07: Moved the updates waiting in Patch/Mod_Framework/Waiting into place before the pick
#      Paulinchen  2026-10-31: Put the files the web installer could not write in place and removed those it could not remove
#      Paulinchen  2026-10-30: Counted the library for JoiPlay as a copy's DLL there
#      Paulinchen  2026-10-28: Created
#
#----------------------------------------------------------------

# Boots the MGQ Paradox Mod Framework once per game session: finds every installed copy, the
# standalone one in Patch/Mod_Framework and any inside a mod's folder (Patch/<mod>/Mod_Framework),
# and loads the loader of the newest copy that has its DLL. Every copy ships these same bytes as
# Patch/!Mod_Framework.rb, whose name sorts before every mod's script, and as boot.rbx. A mod that
# ships only an embedded copy boots it at the top of its script:
#
#   eval(File.read("Patch/My_Mod/Mod_Framework/boot.rbx", encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, "Patch/My_Mod/Mod_Framework/boot.rbx") unless defined?(Mod_Framework)
#
# The game's loader evaluates this file inside a block whose locals every later mod shares, and a
# return there is an error, so this file sets no local and never returns. A failure is written to
# Logs/Mod Framework boot.log and never reaches the game's error box.
begin
  unless defined?(::Mod_Framework) && ::Mod_Framework.respond_to?(:booted?) && ::Mod_Framework.booted?
    unless defined?(::Mod_Framework::Boot)
      module ::Mod_Framework
        # Picks the copy of the framework to load and loads its loader.rbx, which reads the picked
        # copy from here.
        module Boot
          # Where the copies' Version.txt files lie, relative to the game folder: the standalone
          # copy's, and one inside each mod's folder.
          VERSION_FILES = ["Patch/Mod_Framework/Version.txt", "Patch/*/Mod_Framework/Version.txt"]

          # The standalone copy's folder.
          STANDALONE = "Patch/Mod_Framework"

          # The DLL's file name inside a copy's folder.
          DLL = "ModFramework.dll"

          # The file name of the library for JoiPlay inside a copy's folder, which stands for the
          # DLL there.
          ANDROID_LIBRARY = "ModFramework.so"

          # The loader's file name inside a copy's folder.
          LOADER = "loader.rbx"

          # What a Version.txt holds: major, minor and patch, and "-dev" for a build between releases.
          VERSION_FORMAT = /\A(\d+)\.(\d+)\.(\d+)(-dev)?\z/

          # The bytes of a UTF-8 byte order mark, which an editor may put before the version.
          BYTE_ORDER_MARK = [0xEF, 0xBB, 0xBF]

          # The folder whose files the web installer leaves stand-ins for.
          PATCH = "Patch"

          # What ends the stand-in of a file the web installer could not write, beside that file.
          WEB = ".web"

          # What ends the empty marker the web installer leaves beside a file it could not remove.
          REMOVE = ".remove"

          # The waiting folder, where the DLL keeps the updates of mods that ran when they were
          # installed, the framework's own included, until the next start moves them into place.
          WAITING = "Patch/Mod_Framework/Waiting"

          # The list of the waiting folder, which the DLL writes last: a "mod" line (name, version)
          # before the "file" lines (number, target) and "remove" lines (target) of that mod.
          WAITING_LIST = "Waiting.txt"

          # What ends the name of a file moved aside for the one that waited.
          ASIDE = ".old"

          # How long the move waits for a file the game that just closed may still hold, in seconds.
          HELD_WAIT = 3

          # The stub's own log, which needs neither the DLL nor the loader.
          BOOT_LOG = "Logs/Mod Framework boot.log"

          # Moves the waiting updates into place and finishes the web installer's work, then picks
          # the copy to load and loads its loader.
          #
          # @raise [RuntimeError] No copy is installed.
          def self.run
            # A run after a failed one must not count the files the failed run moved in as listed.
            @listed ||= Dir.glob("#{PATCH}/**/*.rb")
            @notes = []
            finish_waiting
            finish_web_install
            found = copies
            copy = pick(found)
            raise "no copy is installed: neither #{VERSION_FILES.join(' nor ')} exists" unless copy

            @notes << "found #{found.map { |candidate| describe(candidate) }.join(', ')}" if found.size > 1
            @folder = copy[:folder]
            @version = copy[:version]
            @dll = copy[:dll]
            file = "#{@folder}/#{LOADER}"
            eval(File.read(file, encoding: "BOM|UTF-8"), TOPLEVEL_BINDING, file)
          end

          # Lists the scripts of PATCH as the game's loader listed them, before the waiting updates and
          # the web installer's stand-ins changed the folder.
          #
          # @return [Array<String>] Their paths relative to the game folder; none before the boot.
          def self.listed
            @listed || []
          end

          # Tells the picked copy's folder.
          #
          # @return [String, nil] The folder relative to the game folder, such as
          #   "Patch/Mod_Framework"; nil before a copy was picked.
          def self.folder
            @folder
          end

          # Tells the picked copy's version as its Version.txt names it.
          #
          # @return [String, nil] The version, such as "0.1.0" or "0.1.0-dev"; nil before a copy
          #   was picked.
          def self.version
            @version
          end

          # Tells whether the picked copy has its DLL.
          #
          # @return [Boolean] Whether its folder holds DLL, or ANDROID_LIBRARY on JoiPlay.
          def self.dll?
            @dll == true
          end

          # Tells what the pick has to say for the framework's log, which the loader writes once
          # the log exists.
          #
          # @return [Array<String>] The lines, such as a copy skipped for a malformed Version.txt.
          def self.notes
            @notes || []
          end

          # Does under Patch what the web installer of mgqonline.org could not, since a browser may
          # not write or remove a file of some names, such as a DLL: each file a ".remove" marker
          # names goes, then the marker, and each "<file>.web" takes the place of <file>. Each step
          # goes into the notes.
          def self.finish_web_install
            Dir.glob("#{PATCH}/**/*#{REMOVE}").sort.each do |marker|
              target = marker[0...-REMOVE.size]
              web_step("removed #{target}, as the web installer asked") do
                File.delete(target) if File.file?(target)
                File.delete(marker)
              end
            end
            Dir.glob("#{PATCH}/**/*#{WEB}").sort.each do |stand_in|
              target = stand_in[0...-WEB.size]
              web_step("put #{stand_in} in the place of #{target}, as the web installer asked") do
                File.delete(target) if File.file?(target)
                File.rename(stand_in, target)
              end
            end
          end

          # Moves the updates of WAITING into place: every file they replace aside first, so a DLL the
          # game that just closed still holds goes too, then the waiting files in, then the files they
          # drop out. A file that stays in use puts the files moved aside back and leaves the updates
          # for the next start; a start cut short is finished by the next, which skips the files
          # moved already. Each step goes into BOOT_LOG; a failure never stops the boot.
          def self.finish_waiting
            return unless File.directory?(WAITING)

            list = "#{WAITING}/#{WAITING_LIST}"
            return clear_waiting unless File.file?(list)

            mods, entries = read_waiting(list)
            moves = entries.select { |kind, staged, _target| kind == :file && File.file?(staged) }
            asides = move_aside(moves)
            return unless asides

            move_in(moves, asides)
            entries.each { |kind, _staged, target| remove_dropped(target) if kind == :remove }
            asides.each { |_target, aside| delete_aside(aside) }
            clear_waiting
            mods.each { |name, version, files, removed| boot_log("moved #{name} #{version} into place: #{files} files, #{removed} removed") }
          rescue StandardError => e
            boot_log("the waiting updates could not be moved into place: #{e.class}: #{e.message}")
          end

          # Reads the list of WAITING; of two lines of one target the later wins.
          #
          # @param list [String] The list.
          # @return [Array] The mods, each [name, version, files, removed], and the entries, each
          #   [:file, waiting file, target] or [:remove, nil, target].
          def self.read_waiting(list)
            mods = []
            entries = {}
            File.open(list, "rb") { |file| file.read }.to_s.force_encoding("UTF-8").split("\n").each do |line|
              parts = line.chomp("\r").split("\t")
              next if parts.empty?

              if parts[0] == "mod" && parts.size == 3
                mods << [parts[1], parts[2], 0, 0]
              elsif waiting_entry?(parts)
                key = parts.last.downcase
                entries.delete(key)
                entries[key] = parts[0] == "file" ? [:file, "#{WAITING}/#{parts[1]}", parts[2]] : [:remove, nil, parts[1]]
                mods.last[parts[0] == "file" ? 2 : 3] += 1 if mods.last
              else
                boot_log("skipped the line #{line.inspect} of #{list}")
              end
            end
            [mods, entries.values]
          end

          # Tells whether the parts of a line of the list name a file to move or to remove inside
          # Patch.
          #
          # @param parts [Array<String>] The line's parts.
          # @return [Boolean] Whether they do.
          def self.waiting_entry?(parts)
            entry = (parts[0] == "file" && parts.size == 3 && parts[1] =~ /\A\d+\z/) || (parts[0] == "remove" && parts.size == 2)
            entry && parts.last =~ %r{\APatch/[^/]} && !parts.last.split("/").include?("..") ? true : false
          end

          # Moves each file a waiting one replaces aside, waiting HELD_WAIT for one the game that just
          # closed still holds.
          #
          # @param moves [Array<Array>] The entries of the waiting files, see read_waiting.
          # @return [Array<Array>, nil] Each target and where it went; nil when one stayed in use,
          #   after every file moved aside went back.
          def self.move_aside(moves)
            done = []
            deadline = Time.now + HELD_WAIT
            moves.each do |_kind, _staged, target|
              next unless File.exist?(target)

              aside = aside_of(target)
              begin
                File.rename(target, aside)
                done << [target, aside]
              rescue SystemCallError => e
                if Time.now < deadline
                  sleep(0.2)
                  retry
                end
                boot_log("#{target} stays in use (#{e.class}), so the waiting updates wait for the next start")
                put_back(done)
                return nil
              end
            end
            done
          end

          # Moves the waiting files into place; a failure puts back each file moved aside whose place
          # stayed empty.
          #
          # @param moves [Array<Array>] The entries of the waiting files.
          # @param asides [Array<Array>] Each target moved aside and where it went.
          def self.move_in(moves, asides)
            moves.each do |_kind, staged, target|
              make_folders(File.dirname(target))
              File.rename(staged, target)
            end
          rescue SystemCallError
            put_back(asides.reject { |target, _aside| File.exist?(target) })
            raise
          end

          # Moves files back from aside.
          #
          # @param asides [Array<Array>] Each target and where it went.
          def self.put_back(asides)
            asides.reverse_each do |target, aside|
              begin
                File.rename(aside, target)
              rescue SystemCallError => e
                boot_log("could not put #{target} back from #{aside}: #{e.class}")
              end
            end
          end

          # Names the place a file goes aside to, past an earlier one that cannot go.
          #
          # @param target [String] The file.
          # @return [String] Such as "Patch/Mod_Framework/ModFramework.dll.old".
          def self.aside_of(target)
            aside = "#{target}#{ASIDE}"
            File.delete(aside) if File.file?(aside)
            aside
          rescue SystemCallError
            "#{File.dirname(target)}/#{Process.pid}-#{File.basename(target)}#{ASIDE}"
          end

          # Deletes a file an update dropped; one in use goes aside instead.
          #
          # @param target [String] The file.
          def self.remove_dropped(target)
            return unless File.file?(target)

            begin
              File.delete(target)
            rescue SystemCallError
              File.rename(target, aside_of(target))
            end
          rescue SystemCallError => e
            boot_log("could not remove #{target}: #{e.class}")
          end

          # Deletes a file moved aside; one still in use stays.
          #
          # @param aside [String] The file.
          def self.delete_aside(aside)
            File.delete(aside)
          rescue SystemCallError => e
            boot_log("left #{aside}, which is still in use (#{e.class})")
          end

          # Deletes WAITING with what is left in it.
          def self.clear_waiting
            Dir.glob("#{WAITING}/*").each { |file| File.delete(file) }
            Dir.rmdir(WAITING)
          end

          # Makes a folder and those above it.
          #
          # @param folder [String] The folder, relative to the game folder.
          def self.make_folders(folder)
            return if folder == "." || File.directory?(folder)

            make_folders(File.dirname(folder))
            Dir.mkdir(folder)
          end

          # Writes a line into BOOT_LOG.
          #
          # @param text [String] The line.
          def self.boot_log(text)
            Dir.mkdir("Logs") unless File.directory?("Logs")
            File.open(BOOT_LOG, "ab") { |file| file.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  #{text}\r\n") }
          rescue StandardError
            nil
          end

          # Runs a step of finish_web_install and notes how it went; a step that fails leaves its
          # files for the next start.
          #
          # @param note [String] What the step did.
          def self.web_step(note)
            yield
            @notes << note
          rescue StandardError => e
            @notes << "#{note.sub(/,.*/, '')} FAILED: #{e.class}: #{e.message}"
          end

          # Finds the installed copies: each folder whose Version.txt names a version.
          #
          # @return [Array<Hash>] Each copy's :folder, :version, :number ([major, minor, patch]),
          #   :dev, :standalone and :dll, in the order of their folders.
          def self.copies
            VERSION_FILES.map { |pattern| Dir.glob(pattern) }.flatten.uniq.sort.map { |file| copy_of(file) }.compact
          end

          # Reads a copy from its Version.txt.
          #
          # @param file [String] The Version.txt.
          # @return [Hash, nil] The copy, see copies; nil when the file names no version.
          def self.copy_of(file)
            folder = File.dirname(file)
            text = File.open(file, "rb") { |handle| handle.read }.to_s
            text = text[3..-1] if text.unpack("C3") == BYTE_ORDER_MARK
            text = text.strip
            parts = VERSION_FORMAT.match(text)
            unless parts
              @notes << "skipped #{folder}: its Version.txt holds #{text[0, 40].inspect}, which is no version"
              return nil
            end

            { :folder => folder, :version => text.force_encoding("US-ASCII"), :number => [parts[1].to_i, parts[2].to_i, parts[3].to_i],
              :dev => !parts[4].nil?, :standalone => folder == STANDALONE, :dll => File.file?("#{folder}/#{library}") }
          end

          # Picks the copy to load: a copy with its DLL before any without, then the highest
          # version, then a "-dev" build before the release of the same number, then the standalone
          # copy.
          #
          # A standalone copy of a higher major version than every embedded copy is skipped, since
          # the mods that embed the framework were built against their own major version.
          #
          # @param copies [Array<Hash>] The copies, see copies.
          # @return [Hash, nil] The copy, nil when there is none.
          def self.pick(copies)
            embedded = copies.reject { |copy| copy[:standalone] }
            unless embedded.empty?
              major = embedded.map { |copy| copy[:number][0] }.max
              copies = copies.reject do |copy|
                skipped = copy[:standalone] && copy[:number][0] > major
                @notes << "skipped the standalone copy #{copy[:version]}: its major version is above every embedded copy's (#{major})" if skipped
                skipped
              end
            end
            copies.max_by { |copy| [copy[:dll] ? 1 : 0] + copy[:number] + [copy[:dev] ? 1 : 0, copy[:standalone] ? 1 : 0] }
          end

          # Describes a copy for the log.
          #
          # @param copy [Hash] The copy, see copies.
          # @return [String] Its version and folder, and whether it has its DLL.
          def self.describe(copy)
            "#{copy[:version]} in #{copy[:folder]}#{copy[:dll] ? '' : " without #{library}"}"
          end

          # Names the file that stands for the DLL where the game runs.
          #
          # @return [String] ANDROID_LIBRARY on JoiPlay, DLL elsewhere.
          def self.library
            $joiplay || RUBY_PLATFORM =~ /android/i ? ANDROID_LIBRARY : DLL
          end
        end
      end
    end
    ::Mod_Framework::Boot.run
  end
rescue Exception
  begin
    Dir.mkdir("Logs") unless File.directory?("Logs")
    File.open("Logs/Mod Framework boot.log", "ab") do |file|
      file.write("#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}  the Mod Framework did not boot: #{$!.class}: #{$!.message} (#{Array($!.backtrace).first})\r\n")
    end
  rescue Exception
    nil
  end
end
