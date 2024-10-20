:-['src/utils.pl'].
:- table transmissionTime/3.
:-['src/sample-data.pl'].

:- set_prolog_flag(answer_write_options,[max_depth(0), spacing(next_argument)]).
:- set_prolog_flag(stack_limit, 64 000 000 000).
:- set_prolog_flag(last_call_optimisation, true).

glbf(Paths, Capacities) :-
    possiblePaths(PPaths, Capacities),
    validPaths(PPaths, Paths).
    
possiblePaths(Paths, Capacities) :-
    findall(FlowId, flow(FlowId, _, _, _, _, _, _, _), FlowIds),
    possiblePaths(FlowIds, Capacities, Paths).
    
validPaths(PPaths, Paths) :-
    findall((F,Path), member((F,(Path,_,_)),PPaths), Paths2),
    compatiblePaths(PPaths, Paths2, Paths).

possiblePaths(FlowIds, Alloc, Out) :- possiblePaths(FlowIds, [], Alloc, [], Out).
possiblePaths([FlowId|FlowIds], Alloc, NewAlloc, OldOut, Out) :-
    possiblePath(FlowId, Alloc, TmpAlloc, FOut),
    possiblePaths(FlowIds, TmpAlloc, NewAlloc, [(FlowId, FOut)|OldOut], Out).
possiblePaths([], Alloc, Alloc, Out, Out).

possiblePath(FlowId, Alloc, NewAlloc, (Path, NewMinB, Delay)) :-
    flow(FlowId, _, _, PacketSize, _, BitRate, Budget, Th),
    MinB is Budget - Th,
    candidate(FlowId, CPath),
    path(CPath, MinB, Alloc, PacketSize, BitRate, NewMinB),
    delay(NewMinB, CPath, Delay), updateCapacities(CPath, BitRate, Alloc, NewAlloc),
    flatPath(CPath, Path).
possiblePath(FlowId, _, _, ([], -1, 0)) :-
    \+ candidate(FlowId, _), !.

path([(S, N)|Rest], OldMinB, Alloc, PacketSize, BitRate, NewMinB) :-
    link(S, N, TProp, Bandwidth),
    hopOK(N, TProp, Bandwidth, Alloc, PacketSize, BitRate, OldMinB, TmpMinB),
    path(Rest, TmpMinB, Alloc, PacketSize, BitRate, NewMinB).
path([], MinB, _, _, _, MinB).

hopOK(N, TProp, Bandwidth, Alloc, PacketSize, BitRate, MinB, NewMinB) :- 
    node(N, MinNodeBudget), usedBandwidth(N, _, Alloc, UsedBW), Bandwidth > UsedBW + BitRate,
    transmissionTime(PacketSize, Bandwidth, TTime),
    NewMinB is MinB - MinNodeBudget - TProp - TTime.

transmissionTime(PacketSize, Bandwidth, TTime) :- TTime is PacketSize/Bandwidth.

delay(PathMinB, [(_,_)], Delay) :- Delay is PathMinB, !.
delay(PathMinB, Path, Delay) :- PathMinB > 0, length(Path, Hops), Delay is PathMinB/Hops.
delay(PathMinB, _, 0) :- PathMinB < 0.

compatiblePaths([(FlowId, (P, MinB, D))|Fs], Paths, [(FlowId, (P, (MinB,MaxB), D))|NewFs]) :-
    flow(FlowId, _, _, PacketSize, BurstSize, _, _, Th), 
    totQTime(P, FlowId, PacketSize, BurstSize, Paths, TotQTime),
    MaxB is MinB + 2*Th - TotQTime, MaxB >= 0,
    compatiblePaths(Fs, Paths, NewFs).
compatiblePaths([], _, []).

totQTime([S,D|Path], FId, PacketSize, BurstSize, Paths, TotQTime) :-
    link(S, D, _, Bandwidth),
    findall(PB, relevantFlow(FId, S, Paths, PB), PBs), sumlist(PBs, Sum),
    QTime is (((BurstSize - 1) * PacketSize) + Sum)/Bandwidth,
    totQTime([D|Path], FId, PacketSize, BurstSize, Paths, TmpQTime),
    TotQTime is QTime + TmpQTime.
totQTime([_], _, _, _, _, 0).

relevantFlow(CurrF, N, Paths, PB) :-
    dif(F, CurrF), member((F,Path),Paths), member(N, Path),
    flow(F,_,_,P,B,_,_,_), PB is P * B.