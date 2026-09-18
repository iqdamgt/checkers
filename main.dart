import 'package:flutter/material.dart';

void main() {
  runApp(const CheckersApp());
}

class CheckersApp extends StatelessWidget {
  const CheckersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Checkers (Dam)',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
        scaffoldBackgroundColor: const Color(0xFF2B2B2B),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}

// ------------------- MODEL -------------------

enum PieceColor { red, black }

class Piece {
  PieceColor color;
  bool isKing;
  Piece(this.color, {this.isKing = false});
}

class Position {
  final int row;
  final int col;
  const Position(this.row, this.col);

  @override
  bool operator ==(Object other) =>
      other is Position && other.row == row && other.col == col;

  @override
  int get hashCode => row * 8 + col;
}

class Move {
  final Position from;
  final Position to;
  final Position? captured; // posisi bidak lawan yang dimakan (jika ada)
  Move(this.from, this.to, {this.captured});
}

// ------------------- GAME SCREEN -------------------

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  // board[row][col], null = kosong
  late List<List<Piece?>> board;
  PieceColor currentTurn = PieceColor.black;
  Position? selected;
  List<Move> legalMovesForSelected = [];
  String? winnerMessage;

  @override
  void initState() {
    super.initState();
    _setupBoard();
  }

  void _setupBoard() {
    board = List.generate(8, (_) => List<Piece?>.filled(8, null));
    // Bidak hitam di baris atas (0-2), merah di baris bawah (5-7)
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = Piece(PieceColor.black);
        }
      }
    }
    for (int row = 5; row < 8; row++) {
      for (int col = 0; col < 8; col++) {
        if ((row + col) % 2 == 1) {
          board[row][col] = Piece(PieceColor.red);
        }
      }
    }
    currentTurn = PieceColor.black;
    selected = null;
    legalMovesForSelected = [];
    winnerMessage = null;
  }

  bool _inBounds(int r, int c) => r >= 0 && r < 8 && c >= 0 && c < 8;

  // Menghitung semua langkah legal untuk satu bidak di posisi [pos]
  List<Move> _movesForPiece(Position pos) {
    final piece = board[pos.row][pos.col];
    if (piece == null) return [];

    List<int> directions;
    if (piece.isKing) {
      directions = [-1, 1];
    } else {
      directions = piece.color == PieceColor.black ? [1] : [-1];
    }

    List<Move> simpleMoves = [];
    List<Move> captureMoves = [];

    for (int dr in directions) {
      for (int dc in [-1, 1]) {
        final r1 = pos.row + dr;
        final c1 = pos.col + dc;
        if (!_inBounds(r1, c1)) continue;

        if (board[r1][c1] == null) {
          simpleMoves.add(Move(pos, Position(r1, c1)));
        } else if (board[r1][c1]!.color != piece.color) {
          final r2 = r1 + dr;
          final c2 = c1 + dc;
          if (_inBounds(r2, c2) && board[r2][c2] == null) {
            captureMoves.add(
              Move(pos, Position(r2, c2), captured: Position(r1, c1)),
            );
          }
        }
      }
    }

    // Aturan sederhana: jika ada langkah makan (capture) untuk bidak ini,
    // langkah biasa tidak ditampilkan sebagai pilihan untuk bidak tsb.
    return captureMoves.isNotEmpty ? captureMoves : simpleMoves;
  }

  // Cek apakah pemain saat ini punya langkah makan yang tersedia di papan
  bool _anyCaptureAvailable(PieceColor color) {
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.color == color) {
          final moves = _movesForPiece(Position(r, c));
          if (moves.any((m) => m.captured != null)) return true;
        }
      }
    }
    return false;
  }

  void _selectPiece(Position pos) {
    final piece = board[pos.row][pos.col];
    if (piece == null || piece.color != currentTurn) return;

    List<Move> moves = _movesForPiece(pos);

    // Jika ada bidak lain milik pemain yang wajib makan, batasi pilihan.
    bool mustCapture = _anyCaptureAvailable(currentTurn);
    if (mustCapture && !moves.any((m) => m.captured != null)) {
      moves = [];
    }

    setState(() {
      selected = pos;
      legalMovesForSelected = moves;
    });
  }

  void _tryMoveTo(Position target) {
    if (selected == null) return;
    final move = legalMovesForSelected.firstWhere(
      (m) => m.to == target,
      orElse: () => Move(selected!, selected!),
    );
    if (move.to == selected) return; // bukan langkah valid

    setState(() {
      final piece = board[move.from.row][move.from.col]!;
      board[move.from.row][move.from.col] = null;
      board[move.to.row][move.to.col] = piece;

      if (move.captured != null) {
        board[move.captured!.row][move.captured!.col] = null;
      }

      // Promosi jadi raja (king) jika sampai baris ujung
      if (!piece.isKing) {
        if (piece.color == PieceColor.black && move.to.row == 7) {
          piece.isKing = true;
        } else if (piece.color == PieceColor.red && move.to.row == 0) {
          piece.isKing = true;
        }
      }

      // Multi-jump sederhana: jika baru saja makan dan masih bisa makan lagi
      // dengan bidak yang sama, pemain lanjut jalan (giliran tidak berpindah).
      bool canChainCapture = false;
      if (move.captured != null) {
        final nextMoves = _movesForPiece(move.to);
        canChainCapture = nextMoves.any((m) => m.captured != null);
      }

      if (canChainCapture) {
        selected = move.to;
        legalMovesForSelected =
            _movesForPiece(move.to).where((m) => m.captured != null).toList();
      } else {
        selected = null;
        legalMovesForSelected = [];
        currentTurn = currentTurn == PieceColor.black
            ? PieceColor.red
            : PieceColor.black;
      }

      _checkWinner();
    });
  }

  void _checkWinner() {
    int redCount = 0;
    int blackCount = 0;
    for (final row in board) {
      for (final p in row) {
        if (p != null) {
          if (p.color == PieceColor.red) redCount++;
          if (p.color == PieceColor.black) blackCount++;
        }
      }
    }

    if (redCount == 0) {
      winnerMessage = 'Hitam Menang!';
      return;
    }
    if (blackCount == 0) {
      winnerMessage = 'Merah Menang!';
      return;
    }

    // Cek apakah pemain giliran sekarang punya langkah sama sekali
    bool hasAnyMove = false;
    for (int r = 0; r < 8; r++) {
      for (int c = 0; c < 8; c++) {
        final p = board[r][c];
        if (p != null && p.color == currentTurn) {
          if (_movesForPiece(Position(r, c)).isNotEmpty) {
            hasAnyMove = true;
            break;
          }
        }
      }
      if (hasAnyMove) break;
    }
    if (!hasAnyMove) {
      winnerMessage = currentTurn == PieceColor.black
          ? 'Merah Menang! (Hitam buntu)'
          : 'Hitam Menang! (Merah buntu)';
    }
  }

  void _restart() {
    setState(() {
      _setupBoard();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkers (Dam)'),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Main lagi',
            onPressed: _restart,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            Text(
              winnerMessage ??
                  'Giliran: ${currentTurn == PieceColor.black ? "Hitam" : "Merah"}',
              style: TextStyle(
                color: winnerMessage != null ? Colors.amberAccent : Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: _buildBoard(),
                  ),
                ),
              ),
            ),
            if (winnerMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: ElevatedButton(
                  onPressed: _restart,
                  child: const Text('Main Lagi'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBoard() {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 64,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 8,
      ),
      itemBuilder: (context, index) {
        final row = index ~/ 8;
        final col = index % 8;
        final pos = Position(row, col);
        final isDark = (row + col) % 2 == 1;
        final piece = board[row][col];

        final isSelected = selected == pos;
        final isTarget = legalMovesForSelected.any((m) => m.to == pos);

        Color squareColor;
        if (isSelected) {
          squareColor = Colors.greenAccent.shade400;
        } else if (isTarget) {
          squareColor = Colors.lightGreenAccent.shade100;
        } else if (isDark) {
          squareColor = const Color(0xFF6B4226);
        } else {
          squareColor = const Color(0xFFE8C99B);
        }

        return GestureDetector(
          onTap: () {
            if (winnerMessage != null) return;
            if (isTarget) {
              _tryMoveTo(pos);
            } else if (piece != null && piece.color == currentTurn) {
              _selectPiece(pos);
            } else if (selected != null) {
              setState(() {
                selected = null;
                legalMovesForSelected = [];
              });
            }
          },
          child: Container(
            color: squareColor,
            padding: const EdgeInsets.all(4),
            child: piece == null ? null : _buildPiece(piece),
          ),
        );
      },
    );
  }

  Widget _buildPiece(Piece piece) {
    final baseColor = piece.color == PieceColor.black
        ? const Color(0xFF1A1A1A)
        : const Color(0xFFB3261E);
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: baseColor,
        border: Border.all(color: Colors.white24, width: 2),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 3,
            offset: Offset(1, 2),
          ),
        ],
      ),
      child: piece.isKing
          ? const Center(
              child: Icon(Icons.star, color: Colors.amber, size: 18),
            )
          : null,
    );
  }
}
