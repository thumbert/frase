import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  runApp(const FraseApp());
}

final gameBank = [
  {
    'input': ['grow', 'trunk'],
    'secret': ['grunt', 'work'],
  },
  {
    'input': ['thorns', 'frill', 'hue'],
    'secret': ['run', 'for', 'the', 'hills'],
  },
  {
    'input': ['stretch', 'fret', 'poem'],
    'secret': ['the', 'perfect', 'storm'],
  },
  {
    'input': ['eagerly', 'nods'],
    'secret': ['golden', 'years'],
  },
];

enum SolutionStatus {
  correct(
    foregroundColor: Color.fromRGBO(14, 124, 112, 1.0),
    backgroundColor: Color.fromRGBO(14, 124, 112, 0.1),
    borderColor: Color.fromRGBO(14, 124, 112, 1.0),
  ),
  unSubmitted(
    foregroundColor: Colors.white,
    backgroundColor: Color(0xFF303030),
    borderColor: Color(0xFF303030),
  ),
  wrong(
    foregroundColor: Colors.red,
    backgroundColor: Colors.white,
    borderColor: Colors.red,
  ),
  empty(
    foregroundColor: Colors.white,
    backgroundColor: Colors.white,
    borderColor: Colors.black,
  );

  const SolutionStatus({
    required this.foregroundColor,
    required this.backgroundColor,
    required this.borderColor,
  });

  final Color foregroundColor;
  final Color backgroundColor;
  final Color borderColor;
}

class InputCell {
  InputCell({
    required this.char,
    required this.index,
    required this.isAvailable,
  }) {
    if (isAvailable) {
      foregroundColor = Colors.grey[850]!;
    } else {
      foregroundColor = Colors.grey[400]!;
    }
    backgroundColor = Colors.white;
  }

  final String char;
  final int index;

  /// is this cell available for selection?
  final bool isAvailable;
  late final Color foregroundColor;
  late final Color backgroundColor;
}

class SolutionCell {
  SolutionCell({
    required this.char,
    required this.index,
    required this.inputCellIndex,
    required this.status,
  });

  /// A solution cell starts empty with char = ''.
  final String char;

  /// The index of the solution cell in the Game [allSolution].
  final int index;

  /// The input cell index is non-null only if the cell is filled
  final int? inputCellIndex;

  final SolutionStatus status;

  SolutionCell.empty()
    : char = '',
      index = 0,
      inputCellIndex = null,
      status = SolutionStatus.empty;
}

/// Input cells
final inputCells = listSignal(<InputCell>[], debugLabel: 'inputCells');

/// Which cells from the input have been used.  They get disabled and
/// can't be reused.
final usedInputCells = listSignal(<int>[], debugLabel: 'usedInputCells');

/// The cells that are used to display the solution.
final solutionCells = listSignal(<SolutionCell>[], debugLabel: 'solutionCells');

final haveUnsubmittedGuesses = computed(() {
  var res = false;
  for (var cell in solutionCells.value) {
    if (cell.status == SolutionStatus.unSubmitted) {
      res = true;
      break;
    }
  }
  return res;
}, debugLabel: 'haveUnsubmittedGuesses');

/// I can't use the cell status to animate the flipping of the cells.
/// Unfortunately, I need an extra state variable.
final cellsToFlip = listSignal(<int>[], debugLabel: 'cellsToFlip');

class Game {
  late final List<String> input;
  late final List<int> shape;
  late final List<String> solution;
  late final String allSolution;

  /// The start index of each row in the input.
  late final List<int> startIndexInput;

  /// The start index of each row in the solution.
  late final List<int> startIndexSolution;

  /// The index of the cell that is currently active (pulsating).  If all cells
  /// are filled, this will be null.  This index is for the solution cells.
  final activeCellIdx = signal<int?>(0, debugLabel: 'activeCellIdx');

  static Game fromBank(int index) {
    final input = gameBank[index];
    var game =
        Game()
          ..input =
              (input['input'] as List)
                  .cast<String>()
                  .map((e) => e.toLowerCase())
                  .toList()
          ..solution =
              (input['secret'] as List)
                  .cast<String>()
                  .map((e) => e.toLowerCase())
                  .toList();
    game.shape = game.solution.map((e) => e.length).toList();
    game.allSolution = game.solution.join('');
    game.startIndexInput = game.input.map((e) => e.length).fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    game.startIndexSolution = game.shape.fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    solutionCells.value = listSignal(
      List.generate(game.phraseLength, (index) => SolutionCell.empty()),
    );
    inputCells.value = listSignal(
      game.input
          .join('')
          .split('')
          .mapIndexed((i, e) => InputCell(char: e, index: i, isAvailable: true))
          .toList(),
    );

    return game;
  }

  /// Is the game complete?  This is true when all solution cells are correct.
  bool get isComplete {
    return solutionCells.value.every(
      (cell) => cell.status == SolutionStatus.correct,
    );
  }

  /// Returns the total number of characters in the phrase.
  int get phraseLength {
    return shape.fold(0, (a, b) => a + b);
  }

  /// Return the next active cell index.  If there are no more empty cells,
  /// return null.
  int? getNextActiveCellIdx() {
    if (usedInputCells.value.length < phraseLength) {
      int? nextIdx = activeCellIdx.value! + 1;
      for (var i = 0; i < solutionCells.value.length; i++) {
        if (nextIdx! >= phraseLength) {
          nextIdx = 0;
        }
        if (solutionCells.value[nextIdx].char == '') {
          return nextIdx;
        }
        nextIdx++;
      }
    }
    return null;
  }
}

class FraseApp extends StatelessWidget {
  const FraseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Frase Me Up',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: const GameScreen());
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late final Game game;

  bool _blink = true;
  Timer? _blinkTimer;
  late AnimationController _controller;
  late Animation<double> _animation;
  late Stopwatch _stopwatch;

  @override
  void initState() {
    super.initState();
    int puzzleNumber = 0;
    game = Game.fromBank(puzzleNumber);
    _stopwatch = Stopwatch()..start();

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      setState(() {
        _blink = !_blink;
      });
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _animation = Tween<double>(begin: 0, end: 1).animate(_controller)
      ..addListener(() {
        setState(() {});
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  /// What happens when you push the Submit button.
  void _submitGuess(BuildContext context) {
    var solutionCells2 = solutionCells.value;
    var cellsToFlip2 = <int>[];
    for (var cell in solutionCells.value) {
      if (cell.status == SolutionStatus.unSubmitted) {
        cellsToFlip2.add(cell.index);
        if (cell.char == game.allSolution[cell.index]) {
          // correct guess
          solutionCells2[cell.index] = SolutionCell(
            char: cell.char,
            index: cell.index,
            inputCellIndex: cell.inputCellIndex,
            status: SolutionStatus.correct,
          );
        } else {
          // wrong guess
          solutionCells2[cell.index] = SolutionCell(
            char: cell.char,
            index: cell.index,
            inputCellIndex: cell.inputCellIndex,
            status: SolutionStatus.wrong,
          );
        }
      }
    }
    solutionCells.value = solutionCells2;
    cellsToFlip.value = cellsToFlip2;
    if (_controller.status != AnimationStatus.forward) {
      _controller.reset();
    }
    _controller.forward();

    if (game.isComplete) {
      Future.delayed(const Duration(seconds: 1), () {
        if (context.mounted) {
          showDialog(
            context: context,
            builder:
                (context) => AlertDialog(
                  title: const Text('Congratulations!'),
                  content: const Text('You completed the puzzle!'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Reset the game or navigate to a new game
                        // setState(() {
                        //   game = Game.fromBank((gameBank.indexOf(game) + 1) %
                        //       gameBank.length);
                        //   _stopwatch.reset();
                        //   _stopwatch.start();
                        // });
                      },
                      child: const Text('Next Puzzle'),
                    ),
                  ],
                ),
          );
        }
      });
    }

    // Reset the wrong cells to empty and return them to the input cells.
    Future.delayed(const Duration(seconds: 1), () {
      var inputCells2 = inputCells.value;
      var solutionCells2 = solutionCells.value;
      for (var cell in solutionCells.value) {
        if (cell.status == SolutionStatus.wrong) {
          solutionCells2[cell.index] = SolutionCell.empty();
          inputCells2[cell.inputCellIndex!] = InputCell(
            char: cell.char,
            index: cell.inputCellIndex!,
            isAvailable: true,
          );
        }
      }
      solutionCells.value = solutionCells2;
      inputCells.value = inputCells2;
    });
  }

  /// What happens when you push the Clear button.
  void _clearGuess() {}

  Widget makeCellWidget(int idx) {
    var cell = solutionCells.value[idx];
    return InkWell(
      onTap: () {
        // reset the active cell to this cell
        game.activeCellIdx.value = idx;
        var solutionCells2 = solutionCells.value;
        solutionCells2[idx] = SolutionCell.empty();
        solutionCells.value = solutionCells2;

        //
        if (cell.char != '') {
          var inputCells2 = inputCells.value;
          inputCells2[cell.inputCellIndex!] = InputCell(
            char: cell.char,
            index: cell.inputCellIndex!,
            isAvailable: true,
          );
          inputCells.value = inputCells2;
        }
      },
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          cellsToFlip.value.contains(idx)
              ? Transform(
                transform: Matrix4.rotationY(_animation.value * 3.14),
                alignment: Alignment.center,
                child: Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    border: Border.all(color: cell.status.borderColor),
                    borderRadius: BorderRadius.circular(8),
                    color:
                        (idx == game.activeCellIdx.value) && _blink
                            ? Colors.grey[300]
                            : cell.status.backgroundColor,
                  ),
                  child: Center(
                    child: Text(
                      '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: cell.status.foregroundColor,
                      ),
                    ),
                  ),
                ),
              )
              : Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  border: Border.all(color: cell.status.borderColor),
                  borderRadius: BorderRadius.circular(8),
                  color:
                      (idx == game.activeCellIdx.value) && _blink
                          ? Colors.grey[300]
                          : cell.status.backgroundColor,
                ),
                child: Center(
                  child: Text(
                    '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: cell.status.foregroundColor,
                    ),
                  ),
                ),
              ),
          Center(
            child: Text(
              cell.char.toUpperCase(),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: cell.status.foregroundColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              children: [
                Text('SCORE: 0'),
                const Spacer(),
                Text(
                  '${_stopwatch.elapsed.inMinutes.toString().padLeft(2, '0')}:${_stopwatch.elapsed.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                  style: TextStyle(color: Color.fromRGBO(14, 124, 112, 1.0)),
                ),
                const Spacer(),
                Icon(Icons.settings, color: Colors.grey[700]),
              ],
            ),
            const Divider(thickness: 1.0),
            const Spacer(),
            Column(
              spacing: 16,
              // mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'TODAY\'S SECRET FRASE',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),

                /// Solution cells
                Column(
                  children: [
                    for (int i = 0; i < game.shape.length; i++)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(game.shape[i], (index) {
                          var idx = game.startIndexSolution[i] + index;
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                              vertical: 8.0,
                            ),
                            child: makeCellWidget(idx),
                          );
                        }),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 48),
            Text(
              "TODAY'S ANAGRAM",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),

            /// Input (original) cells
            Column(
              children: [
                for (int i = 0; i < game.input.length; i++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(game.input[i].length, (index) {
                      var cell =
                          inputCells.value[game.startIndexInput[i] + index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 8.0,
                        ),
                        child: InkWell(
                          onTap: () {
                            if (cell.isAvailable) {
                              var solutionCells2 = solutionCells.value;
                              solutionCells2[game
                                  .activeCellIdx
                                  .value!] = SolutionCell(
                                char: cell.char,
                                index: game.activeCellIdx.value!,
                                inputCellIndex: cell.index,
                                status: SolutionStatus.unSubmitted,
                              );
                              solutionCells.value = solutionCells2;

                              // move the active cell ahead
                              game.activeCellIdx.value =
                                  game.getNextActiveCellIdx();

                              // the input cell is now no longer available
                              var inputCells2 = inputCells.value;
                              inputCells2[game.startIndexInput[i] +
                                  index] = InputCell(
                                char: cell.char,
                                index: cell.index,
                                isAvailable: false,
                              );
                              inputCells.value = inputCells2;
                            }
                          },
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              border: Border.all(color: cell.foregroundColor),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                game.input[i][index].toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: cell.foregroundColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
              ],
            ),

            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed:
                      haveUnsubmittedGuesses.value
                          ? () => _submitGuess(context)
                          : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                  ),
                  child: const Text('Submit'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: haveUnsubmittedGuesses.value ? _clearGuess : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 24,
                    ),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
