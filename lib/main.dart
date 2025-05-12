import 'package:flutter/material.dart';
import 'package:signals/signals_flutter.dart';

sealed class Cell {
  Cell(this.char);
  final String char;
}

class EmptyCell extends Cell {
  EmptyCell() : super('');
}

class CorrectCell extends Cell {
  CorrectCell(super.char);
}

class NotSubmittedCell extends Cell {
  NotSubmittedCell(super.char);
}

class WrongCell extends Cell {
  WrongCell(super.char);
}

class Game {
  late final List<String> input;
  late final List<int> shape;
  late final List<String> solution;

  /// The start index of each row in the input.
  late final List<int> startIndexInput;

  /// The start index of each row in the solution.
  late final List<int> startIndexSolution;
  final activeCellIdx = signal(0);
  final cells = listSignal(<Cell>[]);

  ///
  final usedInputCells = listSignal(<int>[]);

  static Game fromBank(int index) {
    final input = games[index];
    var game =
        Game()
          ..input = (input['input'] as List).cast<String>()
          ..shape = (input['shape'] as List).cast<int>()
          ..solution = (input['secret'] as List).cast<String>();
    game.startIndexInput = game.input.map((e) => e.length).fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    game.startIndexSolution = game.shape.fold(
      [0],
      (sums, element) => sums..add(element + (sums.isEmpty ? 0 : sums.last)),
    )..removeLast();
    game.cells.value = listSignal(
      List.generate(game.phraseLength, (index) => EmptyCell()),
    );
    return game;
  }

  /// Returns the total number of characters in the phrase.
  int get phraseLength {
    return shape.fold(0, (a, b) => a + b);
  }

  int getNextActiveCellIdx() {
    int nextIdx = activeCellIdx.value + 1;
    if (nextIdx >= phraseLength) {
      nextIdx = 0;
    }
    return nextIdx;
  }
}

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
];

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
      appBar: AppBar(title: const Text('Frase')),
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

  final List<TextEditingController> _controllers = [];
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    int puzzleNumber = 0;
    game = Game.fromBank(puzzleNumber);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    for (int i = 0; i < game.phraseLength; i++) {
      _controllers.add(TextEditingController());
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    _fadeController.dispose();
    super.dispose();
  }

  void _submitGuess() {
    final guess =
        _controllers.map((controller) => controller.text).join().toLowerCase();

    if (guess.isNotEmpty) {
      var isCorrect = (guess == game.solution.join().toLowerCase());
      if (isCorrect) {
        // Correct guess, green feedback
        setState(() {});
      } else {
        // Incorrect guess, red feedback with animation
        _fadeController.forward(from: 0);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Watch(
      (context) => Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          spacing: 16,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'GUESS THE SECRET FRASE!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
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
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              border: Border.all(),
                              borderRadius: BorderRadius.circular(8),
                              color:
                                  (game.startIndexSolution[i] + index ==
                                          game.activeCellIdx.value)
                                      ? Colors.grey[300]
                                      : null,
                            ),

                            child: Center(
                              child: Text(
                                game
                                    .cells
                                    .value[game.startIndexSolution[i] + index]
                                    .char
                                    .toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
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
            Text(
              "TODAY'S ANAGRAM",
              style: TextStyle(fontSize: 18, color: Colors.grey[700]),
            ),
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
                            /// TODO: only set it if the cell is not already used!
                            game.cells.value[game
                                .activeCellIdx
                                .value] = NotSubmittedCell(
                              game.input[i][index].toUpperCase(),
                            );
                            game.activeCellIdx.value =
                                game.getNextActiveCellIdx();
                            game.usedInputCells.value = [
                              ...game.usedInputCells.value,
                              game.startIndexInput[i] + index,
                            ];
                          },
                          child: Container(
                            width: 55,
                            height: 55,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color:
                                    game.usedInputCells.value.contains(
                                          game.startIndexInput[i] + index,
                                        )
                                        ? Colors.grey[400]!
                                        : Colors.black,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                game.input[i][index].toUpperCase(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color:
                                      game.usedInputCells.value.contains(
                                            game.startIndexInput[i] + index,
                                          )
                                          ? Colors.grey[400]
                                          : Colors.black,
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
          ],
        ),
      ),
    );
  }
}
