using ErsatzTV.Core.Domain;
using ErsatzTV.Core.Extensions;
using ErsatzTV.Core.Interfaces.Scheduling;

namespace ErsatzTV.Core.Scheduling;

public class ShuffledMediaCollectionEnumerator : IMediaCollectionEnumerator
{
    private readonly CancellationToken _cancellationToken;
    private readonly Lazy<Option<TimeSpan>> _lazyMinimumDuration;
    private readonly int _mediaItemCount;
    private readonly IList<GroupedMediaItem> _mediaItems;
    private CloneableRandom _random;
    private IList<MediaItem> _shuffled;

    public ShuffledMediaCollectionEnumerator(
        IList<GroupedMediaItem> mediaItems,
        CollectionEnumeratorState state,
        CancellationToken cancellationToken)
    {
        CurrentIncludeInProgramGuide = Option<bool>.None;

        _mediaItemCount = mediaItems.Sum(i => 1 + Optional(i.Additional).Flatten().Count());
        _mediaItems = mediaItems;
        _cancellationToken = cancellationToken;

        if (state.Index >= _mediaItems.Count)
        {
            state.Index = 0;
            state.Seed = new Random(state.Seed).Next();
        }

        _random = new CloneableRandom(state.Seed);
        _shuffled = Shuffle(_mediaItems, _random);
        _lazyMinimumDuration =
            new Lazy<Option<TimeSpan>>(() =>
                _shuffled.Bind(i => i.GetNonZeroDuration()).OrderBy(identity).HeadOrNone());

        State = new CollectionEnumeratorState { Seed = state.Seed };
        while (State.Index < state.Index)
        {
            MoveNext(Option<DateTimeOffset>.None);
        }
    }

    public void ResetState(CollectionEnumeratorState state)
    {
        // only re-shuffle if needed
        if (State.Seed != state.Seed)
        {
            _random = new CloneableRandom(state.Seed);
            _shuffled = Shuffle(_mediaItems, _random);
        }

        State.Seed = state.Seed;
        State.Index = state.Index;
    }

    public string SchedulingContextName => "Shuffle";

    public CollectionEnumeratorState State { get; }

    public Option<MediaItem> Current => _shuffled.Any() ? _shuffled[State.Index % _mediaItemCount] : None;
    public Option<bool> CurrentIncludeInProgramGuide { get; }

    public void MoveNext(Option<DateTimeOffset> scheduledAt)
    {
        if (_mediaItemCount == 0)
        {
            return;
        }

        if ((State.Index + 1) % _mediaItemCount == 0)
        {
            // Collect the last N recently-played items to avoid at the start of the next shuffle.
            // Protection scales with collection size: ~20% lookback, capped at 20, minimum 3.
            // Examples: 20 items = 4, 50 items = 10, 100 items = 20, 200+ items = 20.
            int lookback = Math.Max(3, Math.Min(20, _shuffled.Count / 5));
            var recentIds = new HashSet<int>();
            for (int t = Math.Max(0, _shuffled.Count - lookback); t < _shuffled.Count; t++)
            {
                recentIds.Add(_shuffled[t].Id);
            }

            State.Index = 0;
            int attempts = 0;
            do
            {
                State.Seed = _random.Next();
                _random = new CloneableRandom(State.Seed);
                _shuffled = Shuffle(_mediaItems, _random);
                attempts++;
            } while (!_cancellationToken.IsCancellationRequested && _mediaItems.Count > lookback &&
                     _shuffled.Count > 0 && attempts < 20 &&
                     Current.Map(x => x.Id).Map(id => recentIds.Contains(id)).IfNone(false));
        }
        else
        {
            State.Index++;
        }

        if (_mediaItemCount > 0)
        {
            State.Index %= _mediaItemCount;
        }
    }

    public Option<TimeSpan> MinimumDuration => _lazyMinimumDuration.Value;

    public int Count => _shuffled.Count;

    private IList<MediaItem> Shuffle(IEnumerable<GroupedMediaItem> list, CloneableRandom random)
    {
        GroupedMediaItem[] copy = list.ToArray();

        int n = copy.Length;
        while (n > 1)
        {
            n--;
            int k = random.Next(n + 1);
            (copy[k], copy[n]) = (copy[n], copy[k]);
        }

        return GroupedMediaItem.FlattenGroups(copy, _mediaItemCount);
    }
}
