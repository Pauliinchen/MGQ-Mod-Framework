//----------------------------------------------------------------
//  MarshalReader.cs
//
//  Changelog:
//      Paulinchen  2026-11-07: Moved into the framework's project
//                            - Read plain values only, without the game data reading no one called
//      Paulinchen  2026-10-28: Moved into the Mod Framework
//      Paulinchen  2026-10-23: Read game data through a pruner that leaves fields out, builds its own values and seals objects
//                            - Took Integer Hash keys in strict mode
//                            - Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Globalization;
using System.Numerics;
using System.Text;
using System.Text.Unicode;

namespace MGQParadox.ModFramework.Bridge.Ruby;

/// <summary>
/// Reads one Marshal 4.8 dump of a plain value into a <see cref="RubyValue"/> tree, refusing
/// anything else by name.
/// </summary>
/// <remarks>
/// It builds values and never runs code from the data; nesting and every count are bounded by the
/// data, so broken data ends in a <see cref="RubyValueException"/> instead of a crash.
/// </remarks>
internal ref struct MarshalReader
{
    /// <summary>
    /// The largest capacity an Array or Hash reserves before its entries are read.
    /// </summary>
    private const int MaxReservedEntries = 4096;

    /// <summary>
    /// The instance variable that marks a String as UTF-8 (true) or US-ASCII (false).
    /// </summary>
    private const string EncodingFlag = "E";

    /// <summary>
    /// The instance variable that names a String's other encoding.
    /// </summary>
    private const string EncodingNameIvar = "encoding";

    /// <summary>
    /// The dump.
    /// </summary>
    private readonly ReadOnlySpan<byte> _data;

    /// <summary>
    /// The symbols read so far, which later ones may point back to.
    /// </summary>
    private readonly List<string> _symbols = [];

    /// <summary>
    /// The objects read so far, which later ones may point back to.
    /// </summary>
    private readonly List<RubyValue> _objects = [];

    /// <summary>
    /// The places in <see cref="_objects"/> of the Arrays and Hashes still being read.
    /// </summary>
    private readonly HashSet<int> _open = [];

    /// <summary>
    /// The place of the next byte.
    /// </summary>
    private int _position;

    /// <summary>
    /// The nesting of the value being read.
    /// </summary>
    private int _depth;

    /// <summary>
    /// Starts reading.
    /// </summary>
    /// <param name="data">The dump.</param>
    public MarshalReader(ReadOnlySpan<byte> data)
    {
        _data = data;
    }

    /// <summary>
    /// Reads the version and the one value of the dump.
    /// </summary>
    /// <returns>The value.</returns>
    public RubyValue ReadDump()
    {
        byte major = ReadByte();
        byte minor = ReadByte();
        if (major != RubyMarshal.MajorVersion || minor != RubyMarshal.MinorVersion)
        {
            throw Broken($"It is not Marshal 4.8 data (version {major}.{minor}).");
        }

        RubyValue value = ReadValue();
        return _position == _data.Length
            ? value
            : throw Broken($"It has {_data.Length - _position} bytes after its value.");
    }

    /// <summary>
    /// Makes the exception for broken data.
    /// </summary>
    /// <param name="what">What is wrong, as a sentence.</param>
    /// <returns>The exception.</returns>
    private static RubyValueException Broken(string what) => new("Broken Marshal data: " + what);

    /// <summary>
    /// Makes the exception for a value that is no plain value.
    /// </summary>
    /// <param name="what">The value as the message names it, such as "RPG::Item".</param>
    /// <returns>The exception.</returns>
    private static RubyValueException Refused(string what) => new(RubyValue.Refusal(what));

    /// <summary>
    /// Reads the next value, one level deeper.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadValue()
    {
        if (++_depth > RubyValue.MaxDepth)
        {
            throw new RubyValueException(RubyValueException.TooDeep);
        }

        RubyValue value = ReadValueBody();
        _depth--;
        return value;
    }

    /// <summary>
    /// Reads the next value's type and contents.
    /// </summary>
    /// <returns>The value.</returns>
    private RubyValue ReadValueBody()
    {
        int start = _position;
        char type = (char)ReadByte();
        switch (type)
        {
            case '0': return RubyNil.Value;
            case 'T': return RubyBool.True;
            case 'F': return RubyBool.False;
            case 'i': return new RubyInteger(ReadLong());
            case 'l': return Register(ReadBignum());
            case '"': return Register(new RubyString(ReadBytes(), RubyEncoding.Binary));
            case 'I': return ReadWithIvars();
            case '[': return ReadArray();
            case '{': return ReadHash();
            case '@': return Earlier(ReadCount());
            case ':': throw Refused("the Symbol :" + ReadSymbolBody());
            case ';': throw Refused("the Symbol :" + EarlierSymbol(ReadCount()));
            case '}': throw Refused("a Hash with a default value");
            case 'f': throw Refused("the Float " + Encoding.ASCII.GetString(ReadBytes()));
            case '/': throw Refused("a Regexp");
            case 'e': throw Refused("an object extended with " + ReadSymbol());
            case 'o':
            case 'S':
            case 'u':
            case 'U':
            case 'C':
                throw Refused(ReadSymbol());
            case 'c':
            case 'm':
            case 'M':
                throw Refused("the class " + Encoding.UTF8.GetString(ReadBytes()));
            default:
                throw Broken(string.Create(CultureInfo.InvariantCulture, $"It holds the unknown type '{type}' at byte {start}."));
        }
    }

    /// <summary>
    /// Reads a String followed by the instance variables that name its encoding.
    /// </summary>
    /// <returns>The String.</returns>
    private RubyValue ReadWithIvars()
    {
        int place = _objects.Count;
        RubyValue value = ReadValue();
        int count = ReadCount();
        if (value is not RubyString text)
        {
            throw Refused(value.KindName + " with instance variables");
        }

        text = ReadEncoding(text, count);
        if (place < _objects.Count && ReferenceEquals(_objects[place], value))
        {
            _objects[place] = text;
        }

        return text;
    }

    /// <summary>
    /// Reads a String's instance variables and marks it with the encoding they name.
    /// </summary>
    /// <param name="text">The string read as binary.</param>
    /// <param name="count">The number of instance variables.</param>
    /// <returns>The string with its encoding.</returns>
    private RubyString ReadEncoding(RubyString text, int count)
    {
        RubyEncoding encoding = RubyEncoding.Binary;
        string? name = null;
        for (int index = 0; index < count; index++)
        {
            string ivar = ReadSymbol();
            RubyValue value = ReadValue();
            switch (ivar)
            {
                case EncodingFlag:
                    encoding = value is RubyBool { Flag: true } ? RubyEncoding.Utf8 : RubyEncoding.UsAscii;
                    break;
                case EncodingNameIvar:
                    encoding = RubyEncoding.Other;
                    name = value is RubyString encodingName ? encodingName.Text : "?";
                    break;
                default:
                    throw Refused("a String with the instance variable " + ivar);
            }
        }

        RubyString marked = text.Marked(encoding, name);
        CheckText(marked);
        return marked;
    }

    /// <summary>
    /// Refuses a String that is no UTF-8 or binary, or whose bytes break its encoding.
    /// </summary>
    /// <param name="text">The string.</param>
    private static void CheckText(RubyString text)
    {
        ReadOnlySpan<byte> bytes = text.Bytes.Span;
        bool valid = text.Encoding switch
        {
            RubyEncoding.Utf8 => Utf8.IsValid(bytes),
            RubyEncoding.UsAscii => Ascii.IsValid(bytes),
            RubyEncoding.Other => throw Refused(text.KindName),
            _ => true,
        };
        if (!valid)
        {
            throw Refused($"a String marked {text.EncodingName} with bytes outside it");
        }
    }

    /// <summary>
    /// Reads an Array.
    /// </summary>
    /// <returns>The Array.</returns>
    private RubyArray ReadArray()
    {
        int count = ReadCount(bytesEach: 1);
        var array = new RubyArray(Math.Min(count, MaxReservedEntries));
        int place = Register(array, open: true);
        for (int index = 0; index < count; index++)
        {
            array.Add(ReadValue());
        }

        _open.Remove(place);
        return array;
    }

    /// <summary>
    /// Reads a Hash with String and Integer keys; a key read twice keeps its first place and its last
    /// value, as in Ruby.
    /// </summary>
    /// <returns>The Hash.</returns>
    private RubyHash ReadHash()
    {
        int count = ReadCount(bytesEach: 2);
        var hash = new RubyHash(Math.Min(count, MaxReservedEntries));
        int place = Register(hash, open: true);
        for (int index = 0; index < count; index++)
        {
            RubyValue key = ReadValue();
            if (key is not (RubyString or RubyInteger))
            {
                throw Refused(key.KindName + " as a Hash key");
            }

            hash[key] = ReadValue();
        }

        _open.Remove(place);
        return hash;
    }

    /// <summary>
    /// Reads a symbol where only a symbol may stand, such as a class name: new or one read before.
    /// </summary>
    /// <returns>The symbol's name.</returns>
    private string ReadSymbol()
    {
        char type = (char)ReadByte();
        switch (type)
        {
            case ':':
                return ReadSymbolBody();
            case ';':
                return EarlierSymbol(ReadCount());
            case 'I':
                string name = ReadSymbol();
                int count = ReadCount(bytesEach: 2);
                for (int index = 0; index < count; index++)
                {
                    ReadSymbol();
                    ReadValue();
                }

                return name;
            default:
                throw Broken(string.Create(CultureInfo.InvariantCulture, $"It holds '{type}' where a symbol belongs, at byte {_position - 1}."));
        }
    }

    /// <summary>
    /// Reads a new symbol's name and keeps it for later references.
    /// </summary>
    /// <returns>The name.</returns>
    private string ReadSymbolBody()
    {
        string name = Encoding.UTF8.GetString(ReadBytes());
        _symbols.Add(name);
        return name;
    }

    /// <summary>
    /// Reads a number too large for a packed integer.
    /// </summary>
    /// <returns>The number.</returns>
    private RubyInteger ReadBignum()
    {
        bool negative = ReadByte() == '-';
        int shorts = ReadCount(bytesEach: 2);
        BigInteger magnitude = new(Take(shorts * 2), isUnsigned: true, isBigEndian: false);
        return new RubyInteger(negative ? -magnitude : magnitude);
    }

    /// <summary>
    /// Reads a packed integer as Ruby's r_long does.
    /// </summary>
    /// <returns>The number.</returns>
    private long ReadLong()
    {
        sbyte head = (sbyte)ReadByte();
        if (head == 0)
        {
            return 0;
        }

        if (head > 4)
        {
            return head - 5;
        }

        if (head < -4)
        {
            return head + 5;
        }

        int length = Math.Abs(head);
        long value = head > 0 ? 0 : -1;
        for (int index = 0; index < length; index++)
        {
            value &= ~(0xFFL << (8 * index));
            value |= (long)ReadByte() << (8 * index);
        }

        return value;
    }

    /// <summary>
    /// Reads a count or a reference, and checks that the data left can hold what it counts.
    /// </summary>
    /// <param name="bytesEach">The fewest bytes each counted entry takes; 0 for a reference.</param>
    /// <returns>The count.</returns>
    private int ReadCount(int bytesEach = 0)
    {
        long count = ReadLong();
        if (count < 0 || count > int.MaxValue || count * bytesEach > _data.Length - _position)
        {
            throw Broken(string.Create(CultureInfo.InvariantCulture, $"It names {count} entries at byte {_position}, more than it holds."));
        }

        return (int)count;
    }

    /// <summary>
    /// Reads a length and that many bytes.
    /// </summary>
    /// <returns>A copy of the bytes.</returns>
    private byte[] ReadBytes() => Take(ReadCount(bytesEach: 1)).ToArray();

    /// <summary>
    /// Takes the next bytes.
    /// </summary>
    /// <param name="count">How many.</param>
    /// <returns>The bytes.</returns>
    private ReadOnlySpan<byte> Take(int count)
    {
        if (count > _data.Length - _position)
        {
            throw Broken("It ends inside a value.");
        }

        ReadOnlySpan<byte> bytes = _data.Slice(_position, count);
        _position += count;
        return bytes;
    }

    /// <summary>
    /// Reads the next byte.
    /// </summary>
    /// <returns>The byte.</returns>
    private byte ReadByte() => _position < _data.Length ? _data[_position++] : throw Broken("It ends inside a value.");

    /// <summary>
    /// Finds an object read before, which a reference points back to.
    /// </summary>
    /// <param name="place">The reference.</param>
    /// <returns>The object.</returns>
    private readonly RubyValue Earlier(int place)
    {
        if (place >= _objects.Count)
        {
            throw Broken(string.Create(CultureInfo.InvariantCulture, $"It points to object {place}, which it does not hold yet."));
        }

        RubyValue value = _objects[place];
        return _open.Contains(place) ? throw Refused(value.KindName + " that holds itself") : value;
    }

    /// <summary>
    /// Finds a symbol read before, which a reference points back to.
    /// </summary>
    /// <param name="place">The reference.</param>
    /// <returns>The symbol's name.</returns>
    private readonly string EarlierSymbol(int place) =>
        place < _symbols.Count
            ? _symbols[place]
            : throw Broken(string.Create(CultureInfo.InvariantCulture, $"It points to symbol {place}, which it does not hold yet."));

    /// <summary>
    /// Keeps an object for later references.
    /// </summary>
    /// <typeparam name="T">The object's type.</typeparam>
    /// <param name="value">The object.</param>
    /// <returns>The object.</returns>
    private readonly T Register<T>(T value)
        where T : RubyValue
    {
        _objects.Add(value);
        return value;
    }

    /// <summary>
    /// Keeps an Array or Hash for later references before its contents are read.
    /// </summary>
    /// <param name="value">The container.</param>
    /// <param name="open">Whether it is still being read.</param>
    /// <returns>Its place.</returns>
    private readonly int Register(RubyValue value, bool open)
    {
        _objects.Add(value);
        int place = _objects.Count - 1;
        if (open)
        {
            _open.Add(place);
        }

        return place;
    }
}
