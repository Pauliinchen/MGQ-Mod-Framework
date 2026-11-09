//----------------------------------------------------------------
//  PictureScale.cs
//
//  Changelog:
//      Paulinchen  2026-11-09: Created
//
//----------------------------------------------------------------

using System;
using System.Collections.Generic;
using System.Linq;
using MGQParadox.ModFramework.Bridge;
using MGQParadox.ModFramework.Bridge.Ruby;

namespace MGQParadox.ModFramework.Ui.Pictures;

/// <summary>
/// How a picture fills its room.
/// </summary>
internal enum PictureFit
{
    /// <summary>All of it shows, as large as the room lets it be.</summary>
    Contain,

    /// <summary>It fills the room; what sticks out is cut.</summary>
    Cover,

    /// <summary>It is stretched to the room.</summary>
    Fill,
}

/// <summary>
/// How a picture's pixels scale.
/// </summary>
internal enum PictureSampling
{
    /// <summary>Each pixel takes the nearest pixel of the picture, so pixel art stays crisp.</summary>
    Sharp,

    /// <summary>Each pixel blends the pixels it lies between.</summary>
    Smooth,
}

/// <summary>
/// How one side of a picture is scaled.
/// </summary>
internal enum ScaleWay
{
    /// <summary>The side keeps its length and is copied.</summary>
    Copy,

    /// <summary>Each pixel of the side is taken from the samples.</summary>
    Samples,

    /// <summary>The side is shrunk in one stretch, which the game smooths.</summary>
    Stretch,
}

/// <summary>
/// One pixel of a scaled side: the line of the picture it takes, and the line it blends toward at a
/// weight from 0 (none of it) to 255.
/// </summary>
/// <param name="From">The line it takes.</param>
/// <param name="Toward">The line it blends toward.</param>
/// <param name="Weight">How much of that line it takes, 0 to 255.</param>
internal readonly record struct ScaleSample(int From, int Toward, int Weight);

/// <summary>
/// How one side of a picture is scaled.
/// </summary>
/// <param name="Way">The way.</param>
/// <param name="Samples">Each pixel's sample with <see cref="ScaleWay.Samples"/>, else none.</param>
internal sealed record SideScale(ScaleWay Way, IReadOnlyList<ScaleSample> Samples);

/// <summary>
/// How a picture is scaled into its room.
/// </summary>
/// <param name="Width">Its scaled width.</param>
/// <param name="Height">Its scaled height.</param>
/// <param name="Across">How its width scales, column by column.</param>
/// <param name="Down">How its height scales, row by row.</param>
internal sealed record PictureScalePlan(int Width, int Height, SideScale Across, SideScale Down);

/// <summary>
/// Plans how a picture scales into its room at any factor, keeping its proportions unless it is
/// stretched, with its pixels sharp or smooth; the scripts carry the plan out with the game's
/// copies.
/// </summary>
internal static class PictureScale
{
    /// <summary>
    /// Plans a picture's scaling: [width, height, room width, room height, fit ("contain", "cover"
    /// or "fill"), sampling ("sharp" or "smooth")]; answers [width, height, across, down], each side
    /// [way ("copy", "samples" or "stretch"), [[from, toward, weight], ...]], nil without a picture
    /// or a room.
    /// </summary>
    public const string Topic = "ui.picture.scale";

    /// <summary>
    /// The weight of a line taken whole.
    /// </summary>
    private const int Whole = 255;

    /// <summary>
    /// Registers the topic on a context.
    /// </summary>
    /// <param name="context">The context the handshake opened.</param>
    public static void Register(BridgeContext context)
    {
        ArgumentNullException.ThrowIfNull(context);
        context.Register(Topic, (_, request) => Answer(request.AsArray()));
    }

    /// <summary>
    /// Plans how a picture scales into a room.
    /// </summary>
    /// <param name="width">The picture's width.</param>
    /// <param name="height">Its height.</param>
    /// <param name="roomWidth">The room's width.</param>
    /// <param name="roomHeight">Its height.</param>
    /// <param name="fit">How it fills the room.</param>
    /// <param name="sampling">How its pixels scale.</param>
    /// <returns>The plan, null without a picture or a room.</returns>
    public static PictureScalePlan? Plan(int width, int height, int roomWidth, int roomHeight, PictureFit fit, PictureSampling sampling)
    {
        if (width <= 0 || height <= 0 || roomWidth <= 0 || roomHeight <= 0)
        {
            return null;
        }

        (int scaledWidth, int scaledHeight) = Fitted(width, height, roomWidth, roomHeight, fit);
        return new PictureScalePlan(scaledWidth, scaledHeight, Side(width, scaledWidth, sampling), Side(height, scaledHeight, sampling));
    }

    /// <summary>
    /// Tells a picture's size in a room: by one factor for both sides with <see cref="PictureFit.Contain"/>
    /// and <see cref="PictureFit.Cover"/>, so its proportions stay, the room's own with
    /// <see cref="PictureFit.Fill"/>.
    /// </summary>
    /// <param name="width">The picture's width.</param>
    /// <param name="height">Its height.</param>
    /// <param name="roomWidth">The room's width.</param>
    /// <param name="roomHeight">Its height.</param>
    /// <param name="fit">How it fills the room.</param>
    /// <returns>The width and height, each at least a pixel.</returns>
    private static (int Width, int Height) Fitted(int width, int height, int roomWidth, int roomHeight, PictureFit fit)
    {
        if (fit == PictureFit.Fill)
        {
            return (roomWidth, roomHeight);
        }

        double across = (double)roomWidth / width;
        double down = (double)roomHeight / height;
        double factor = fit == PictureFit.Cover ? Math.Max(across, down) : Math.Min(across, down);
        return (Math.Max(Round(width * factor), 1), Math.Max(Round(height * factor), 1));
    }

    /// <summary>
    /// Plans one side: a copy at its own length; sharp, each pixel the nearest line; smooth, a
    /// shrink in one stretch and an enlargement blending the two lines each pixel's middle lies
    /// between.
    /// </summary>
    /// <param name="from">The side's length in the picture.</param>
    /// <param name="to">Its scaled length.</param>
    /// <param name="sampling">How its pixels scale.</param>
    /// <returns>The side's plan.</returns>
    private static SideScale Side(int from, int to, PictureSampling sampling)
    {
        if (from == to)
        {
            return new SideScale(ScaleWay.Copy, []);
        }

        if (sampling == PictureSampling.Smooth && to < from)
        {
            return new SideScale(ScaleWay.Stretch, []);
        }

        var samples = new ScaleSample[to];
        for (int at = 0; at < to; at++)
        {
            samples[at] = sampling == PictureSampling.Sharp ? Nearest(at, from, to) : Blended(at, from, to);
        }

        return new SideScale(ScaleWay.Samples, samples);
    }

    /// <summary>
    /// Tells the line a scaled pixel takes whole: the one under its middle.
    /// </summary>
    /// <param name="at">The pixel.</param>
    /// <param name="from">The side's length in the picture.</param>
    /// <param name="to">Its scaled length.</param>
    /// <returns>The sample.</returns>
    private static ScaleSample Nearest(int at, int from, int to)
    {
        int line = (int)Math.Min(((2L * at) + 1) * from / (2L * to), from - 1);
        return new ScaleSample(line, line, 0);
    }

    /// <summary>
    /// Tells the two lines a scaled pixel's middle lies between and how far toward the second.
    /// </summary>
    /// <param name="at">The pixel.</param>
    /// <param name="from">The side's length in the picture.</param>
    /// <param name="to">Its scaled length.</param>
    /// <returns>The sample.</returns>
    private static ScaleSample Blended(int at, int from, int to)
    {
        double middle = Math.Clamp(((at + 0.5) * from / to) - 0.5, 0, from - 1);
        int line = (int)Math.Floor(middle);
        int toward = Math.Min(line + 1, from - 1);
        return new ScaleSample(line, toward, toward == line ? 0 : Round((middle - line) * Whole));
    }

    /// <summary>
    /// Answers a plan.
    /// </summary>
    /// <param name="request">See <see cref="Topic"/>.</param>
    /// <returns>The answer, nil without a picture or a room.</returns>
    /// <exception cref="BridgeRequestException">The fit or the sampling is unknown.</exception>
    private static RubyValue Answer(RubyArray request)
    {
        PictureScalePlan? plan = Plan(request[0].AsInt(), request[1].AsInt(), request[2].AsInt(), request[3].AsInt(), FitOf(request[4].AsText()),
                                      SamplingOf(request[5].AsText()));
        return plan is null ? RubyNil.Value : new RubyArray { plan.Width, plan.Height, SideOf(plan.Across), SideOf(plan.Down) };
    }

    /// <summary>
    /// Writes a side's plan as the scripts read it.
    /// </summary>
    /// <param name="side">The side.</param>
    /// <returns>[way, [[from, toward, weight], ...]].</returns>
    private static RubyArray SideOf(SideScale side) =>
        new()
        {
            side.Way.ToString().ToLowerInvariant(),
            new RubyArray(side.Samples.Select(sample => (RubyValue)new RubyArray { sample.From, sample.Toward, sample.Weight })),
        };

    /// <summary>
    /// Reads a fit by its name.
    /// </summary>
    /// <param name="name">"contain", "cover" or "fill".</param>
    /// <returns>The fit.</returns>
    /// <exception cref="BridgeRequestException">No fit is named so.</exception>
    private static PictureFit FitOf(string name) => name switch
    {
        "contain" => PictureFit.Contain,
        "cover" => PictureFit.Cover,
        "fill" => PictureFit.Fill,
        _ => throw new BridgeRequestException($"No fit is named {name}."),
    };

    /// <summary>
    /// Reads a sampling by its name.
    /// </summary>
    /// <param name="name">"sharp" or "smooth".</param>
    /// <returns>The sampling.</returns>
    /// <exception cref="BridgeRequestException">No sampling is named so.</exception>
    private static PictureSampling SamplingOf(string name) => name switch
    {
        "sharp" => PictureSampling.Sharp,
        "smooth" => PictureSampling.Smooth,
        _ => throw new BridgeRequestException($"No sampling is named {name}."),
    };

    /// <summary>
    /// Rounds as Ruby's <c>Float#round</c> does, halves away from zero.
    /// </summary>
    /// <param name="value">The value.</param>
    /// <returns>The whole number.</returns>
    private static int Round(double value) => (int)Math.Round(value, MidpointRounding.AwayFromZero);
}
