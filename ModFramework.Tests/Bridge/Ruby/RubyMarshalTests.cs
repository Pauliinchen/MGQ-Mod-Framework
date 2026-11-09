//----------------------------------------------------------------
//  RubyMarshalTests.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Wrote the dumps Ruby made in the tests instead of reading fixtures
//                            - Moved into the framework's project
//                            - Removed the checks of game data read in full mode and through a pruner
//                            - Took the framework's name as the example text
//      Paulinchen  2026-11-06: Checked that a binary String of UTF-8 reads as text
//      Paulinchen  2026-11-04: Checked the golden files in one round trip, the refusals of strict mode in one test and the
//                              pruned reads in one test
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Checked a pruned read of game data
//                            - Expected Integer Hash keys to cross and an Array key to be refused
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Linq;
using System.Numerics;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Tests.Bridge.Ruby;

/// <summary>
/// Covers the Marshal codec against dumps Ruby 3.3 wrote, as hex: plain values both ways and the
/// refusals of what is no plain value.
/// </summary>
public sealed class RubyMarshalTests
{
    /// <summary>
    /// Ruby 3.3's <c>Marshal.dump</c>, on Windows, whose 32-bit long writes integers past the Fixnum
    /// range of RGSS3's Ruby as Bignums, of <c>{ "scalars" => [nil, true, false], "numbers" => [0,
    /// 122, 123, -124, 256, -257, 65536, 2**30 - 1, 2**30, -(2**30) - 1, 2**31, -(2**64) - 1,
    /// 2**100], "strings" => ["ルカ é", "", 42.to_s, "\x00\xFF raw".b], "nested" => { "seat" => 2,
    /// "names" => ["Alice", "Ilias"], "empty" => {}, "list" => [[1, [2, []]]] }, "rows" => [{ "id"
    /// => 1 }, { "id" => 2 }], "keys" => { 1 => "one", 2**31 => "big" } }</c>, in which the second
    /// "id" is a link to the first.
    /// </summary>
    private const string RubyDump = "04087b0b49220c7363616c617273063a0645545b0830544649220c6e756d62657273063b00545b126900697f69017b69"
        + "ff846902000169fefffe69030000016904ffffff3f6c2b07000000406c2d07010000406c2b07000000806c2d0a010000"
        + "000000000001006c2b0c000000000000000000000000100049220c737472696e6773063b00545b0949220ee383abe382"
        + "ab20c3a9063b0054492200063b00544922073432063b0046220b00ff2072617749220b6e6573746564063b00547b0949"
        + "220973656174063b0054690749220a6e616d6573063b00545b0749220a416c696365063b005449220a496c696173063b"
        + "005449220a656d707479063b00547b004922096c697374063b00545b065b0769065b0769075b00492209726f7773063b"
        + "00545b077b064922076964063b005469067b06402669074922096b657973063b00547b0769064922086f6e65063b0054"
        + "6c2b0700000080492208626967063b0054";

    /// <summary>
    /// Asserts that the plain values Ruby wrote read and write back to the same bytes, that the
    /// numbers around the Fixnum range of RGSS3 and past 64 bits read as Ruby wrote them, that a
    /// String keeps the encoding Ruby marked it with, a binary one read as text only when it holds
    /// UTF-8, that a Hash keeps its order and a value Ruby linked twice reads twice, and that a value
    /// built in C# reads back equal, an ASCII key found under either encoding.
    /// </summary>
    [Fact]
    public void ReadThenWrite_GivesTheValuesAndTheBytesRubyWrote()
    {
        byte[] dump = Convert.FromHexString(RubyDump);
        RubyHash value = RubyMarshal.Read(dump).AsHash();

        Assert.True(dump.AsSpan().SequenceEqual(RubyMarshal.Write(value)), "the dump does not write back to the bytes Ruby wrote");

        RubyArray strings = value["strings"].AsArray();
        RubyHash nested = value["nested"].AsHash();
        BigInteger[] numbers = [0, 122, 123, -124, 256, -257, 65536, (1 << 30) - 1, 1 << 30, -(1 << 30) - 1, BigInteger.Pow(2, 31), -BigInteger.Pow(2, 64) - 1, BigInteger.Pow(2, 100)];

        Assert.Equal(numbers, value["numbers"].AsArray().Select(number => ((RubyInteger)number).Value));
        Assert.Equal(
            new[] { RubyEncoding.Utf8, RubyEncoding.Utf8, RubyEncoding.UsAscii, RubyEncoding.Binary },
            strings.Select(text => ((RubyString)text).Encoding));
        Assert.Equal(("ルカ é", "42"), (strings[0].AsText(), strings[2].AsText()));
        Assert.Throws<RubyValueException>(() => strings[3].AsText());
        Assert.Equal("Mod Framework ルカ", RubyString.Binary("Mod Framework ルカ"u8).AsText());
        Assert.Equal(new[] { "seat", "names", "empty", "list" }, nested.Keys.Select(key => key.AsText()));
        Assert.Equal("Ilias", nested["names"].AsArray()[1].AsText());
        Assert.Equal(new[] { 1, 2 }, value["rows"].AsArray().Select(row => row.AsHash()["id"].AsInt()));

        // Ruby's dump of a = "same"; [a, a].
        Assert.Equal(new[] { "same", "same" }, RubyMarshal.Read(Convert.FromHexString("04085b0749220973616d65063a0645544006")).AsArray().Select(item => item.AsText()));

        var built = new RubyHash
        {
            { "id", 7 },
            { "names", new RubyArray { "Alice", RubyString.Binary([0, 1, 2]) } },
            { "big", BigInteger.Pow(2, 70) },
            { "none", RubyNil.Value },
        };
        RubyHash read = RubyMarshal.Read(RubyMarshal.Write(built)).AsHash();

        Assert.Equal(built, read);
        Assert.Equal(7, read[new RubyString("id"u8.ToArray(), RubyEncoding.UsAscii)].AsInt());
    }

    /// <summary>
    /// Asserts that a read refuses, and names, each kind of value that is no plain value, a String
    /// marked UTF-8 whose bytes are not UTF-8, and data cut short, followed by more bytes or of
    /// another version, and that the writer refuses a Hash key that is no String or Integer.
    /// </summary>
    [Fact]
    public void Read_RefusesWhatIsNoPlainValue()
    {
        // Each is Ruby's dump of the value named.
        (string Dump, string Refusal)[] refused =
        [
            ("04086f3a0e5250473a3a4974656d073a0840696469063a0a406e616d6549220948657262063a064554", "RPG::Item cannot cross the bridge."), // RPG::Item.new(1, "Herb")
            ("04085b063a0973656174", "The Symbol :seat cannot cross the bridge."), // [:seat]
            ("04085b066608312e35", "The Float 1.5 cannot cross the bridge."), // [1.5]
            ("0408753a0a5461626c651d010000000200000001000000010000000200000001000200", "Table cannot cross the bridge."), // a Table of 1 and 2
            ("0408492209838b834a063a0d656e636f64696e67220e53686966745f4a4953", "A String in Shift_JIS cannot cross the bridge."), // "ルカ" in Shift_JIS
            ("04087b065b0669064922086f6e65063a064554", "An Array as a Hash key cannot cross the bridge."), // { [1] => "one" }
            ("04085b064000", "An Array that holds itself cannot cross the bridge."), // a = []; a << a
            ("04087d0649220661063a06455469066900", "A Hash with a default value cannot cross the bridge."), // Hash.new(0) with "a" => 1
        ];

        foreach (var (dump, refusal) in refused)
        {
            Assert.Equal(refusal, Assert.Throws<RubyValueException>(() => RubyMarshal.Read(Convert.FromHexString(dump))).Message);
        }

        byte[] brokenUtf8 = [4, 8, (byte)'I', (byte)'"', 6, 0xFF, 6, (byte)':', 6, (byte)'E', (byte)'T'];
        Assert.Equal("A String marked UTF-8 with bytes outside it cannot cross the bridge.", Assert.Throws<RubyValueException>(() => RubyMarshal.Read(brokenUtf8)).Message);

        foreach (byte[] broken in new byte[][] { [4, 8, (byte)'[', 7, (byte)'T'], [4, 8, (byte)'T', (byte)'T'], [4, 9, (byte)'T'] })
        {
            Assert.StartsWith("Broken Marshal data: ", Assert.Throws<RubyValueException>(() => RubyMarshal.Read(broken)).Message);
        }

        var value = new RubyArray { 1, new RubyHash { { new RubyArray { 1 }, "one" } } };
        Assert.Equal("An Array as a Hash key cannot cross the bridge.", Assert.Throws<RubyValueException>(() => RubyMarshal.Write(value)).Message);
        Assert.False(value.IsPlain(out string? reason));
        Assert.Equal("An Array as a Hash key cannot cross the bridge.", reason);
    }
}
