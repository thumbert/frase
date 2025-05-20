import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

void main() {
  runApp(const FraseApp());
}

final games = [
  {
    'input': ['grow', 'trunk'],
    'shape': [5, 4],
    'secret': ['grunt', 'work'],
  },
  {
    'input': ['thorns', 'frill', 'hue'],
    'shape': [3, 3, 3, 5],
    'secret': ['run', 'for', 'the', 'hills'],
  },
  {
    'input': ['stretch', 'fret', 'poem'],
    'shape': [3, 6, 5],
    'secret': ['the', 'perfect', 'storm'],
  },
];

enum SolutionStatus { correct, unchecked, wrong }

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
  final bool isAvailable;
  late final Color foregroundColor;
  late final Color backgroundColor;
}

class SolutionCell {
  SolutionCell({
    required this.char,
    required this.index,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.inputSourceIndex,
  });

  /// A solution cell starts empty with char = ''.
  final String char;
  final int index;
  final Color foregroundColor;
  final Color backgroundColor;

  /// The input source index is non-null only if the cell is filled
  final int? inputSourceIndex;

  SolutionCell.empty()
    : char = '',
      index = 0,
      foregroundColor = Colors.white,
      backgroundColor = Colors.white,
      inputSourceIndex = null;
}

/// Which cells from the input have been used.  They get disabled and
/// can't be reused.
final usedInputCells = listSignal(<int>[], debugLabel: 'usedInputCells');

class Game {
  late final List<String> input;
  late final List<int> shape;
  late final List<String> solution;

  /// The start index of each row in the input.
  late final List<int> startIndexInput;

  /// The start index of each row in the solution.
  late final List<int> startIndexSolution;

  /// The index of the cell that is currently active.  If all cells are filled,
  /// this will be null.  This index is for the solution cells.
  final activeCellIdx = signal<int?>(0, debugLabel: 'activeCellIdx');

  /// The cells that are used to display the solution.
  final solutionCells = listSignal(
    <SolutionCell>[],
    debugLabel: 'solutionCells',
  );

  /// Input cells
  final inputCells = listSignal(<InputCell>[], debugLabel: 'inputCells');

  static Game fromBank(int index) {
    final input = games[index];
    var game =
        Game()
          ..input =
              (input['input'] as List)
                  .cast<String>()
                  .map((e) => e.toLowerCase())
                  .toList()
          ..shape = (input['shape'] as List).cast<int>()
          ..solution =
              (input['secret'] as List)
                  .cast<String>()
                  .map((e) => e.toLowerCase())
                  .toList();
    game.startIndexInput = game.input.map((e) => e.length).fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    game.startIndexSolution = game.shape.fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    game.solutionCells.value = listSignal(
      List.generate(game.phraseLength, (index) => SolutionCell.empty()),
    );
    game.inputCells.value = listSignal(
      game.input
          .join('')
          .split('')
          .mapIndexed((i, e) => InputCell(char: e, index: i, isAvailable: true))
          .toList(),
    );

    return game;
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
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      body: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late final Game game;

  bool _blink = true;
  Timer? _blinkTimer;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    int puzzleNumber = 0;
    game = Game.fromBank(puzzleNumber);

    _blinkTimer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      setState(() {
        _blink = !_blink;
      });
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _submitGuess() {}

  @override
  Widget build(BuildContext context) {
    return Watch(
      (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Divider(),
            const Text(
              'TODAY\'S SECRET FRASE',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            /// Cells with solution
            Column(
              children: [
                for (int i = 0; i < game.shape.length; i++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      game.shape[i],
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 8.0,
                        ),
                        child: InkWell(
                          onTap: () {
                            // reset the active cell to this cell
                            var idx = game.startIndexSolution[i] + index;
                            var cell = game.solutionCells.value[idx];
                            game.activeCellIdx.value = idx;
                            var solutionCells = game.solutionCells.value;
                            solutionCells[idx] = SolutionCell.empty();
                            game.solutionCells.value = solutionCells;

                            //
                            if (cell.char != '') {
                              var inputCells = game.inputCells.value;
                              inputCells[cell.inputSourceIndex!] = InputCell(
                                char: cell.char,
                                index: cell.inputSourceIndex!,
                                isAvailable: true,
                              );
                              game.inputCells.value = inputCells;
                            }
                          },
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(8),
                              color:
                                  (game.startIndexSolution[i] + index ==
                                              game.activeCellIdx.value) &&
                                          _blink
                                      ? Colors.grey[300]
                                      : game
                                          .solutionCells
                                          .value[game.startIndexSolution[i] +
                                              index]
                                          .backgroundColor,
                            ),

                            child: Center(
                              child: Text(
                                game
                                    .solutionCells
                                    .value[game.startIndexSolution[i] + index]
                                    .char
                                    .toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      game
                                          .solutionCells
                                          .value[game.startIndexSolution[i] +
                                              index]
                                          .foregroundColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            Text(
              "TODAY'S ANAGRAM",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),

            /// Cells with input
            Column(
              children: [
                for (int i = 0; i < game.input.length; i++)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      game.input[i].length,
                      (index) => Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4.0,
                          vertical: 8.0,
                        ),
                        child: InkWell(
                          onTap: () {
                            var cell =
                                game.inputCells.value[game.startIndexInput[i] +
                                    index];
                            if (cell.isAvailable) {
                              var solutionCells = game.solutionCells.value;
                              solutionCells[game
                                  .activeCellIdx
                                  .value!] = SolutionCell(
                                char: cell.char,
                                index: game.activeCellIdx.value!,
                                foregroundColor: Colors.white,
                                backgroundColor: Colors.grey[850]!,
                                inputSourceIndex: cell.index,
                              );
                              game.solutionCells.value = solutionCells;

                              // move the active cell ahead
                              game.activeCellIdx.value =
                                  game.getNextActiveCellIdx();

                              // the input cell is now no longer available
                              var inputCells = game.inputCells.value;
                              inputCells[game.startIndexInput[i] +
                                  index] = InputCell(
                                char: cell.char,
                                index: cell.index,
                                isAvailable: false,
                              );
                            }
                          },
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    game
                                        .inputCells
                                        .value[game.startIndexInput[i] + index]
                                        .foregroundColor,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                game.input[i][index].toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      game
                                          .inputCells
                                          .value[game.startIndexInput[i] +
                                              index]
                                          .foregroundColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _submitGuess,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 24,
                ),
              ),
              child: const Text('Submit'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}



            // Expanded(
            //   child: ValueListenableBuilder<List<String>>(
            //     valueListenable: _guessHistory,
            //     builder: (context, guesses, _) {
            //       return ListView.builder(
            //         itemCount: guesses.length,
            //         itemBuilder: (context, index) {
            //           final guess = guesses[index];
            //           final isCorrect = guess == _secretPhrase.value;

            //           return FadeTransition(
            //             opacity: _fadeController,
            //             child: ListTile(
            //               title: Text(
            //                 guess,
            //                 style: TextStyle(
            //                   color: isCorrect ? Colors.green : Colors.red,
            //                   fontSize: 18,
            //                   fontWeight: FontWeight.bold,
            //                 ),
            //               ),
            //             ),
            //           );
            //         },
            //       );
            //     },
            //   ),
            // ),
