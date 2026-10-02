import { Chess, Square } from 'chess.js';

/**
 * Returns true if moving the piece at `from` to `to` on the given `chess`
 * instance constitutes a pawn promotion.
 *
 * Uses chess.moves() — the set of *legal future moves* — so the check is
 * always correct regardless of what squares appear in move history.
 */
export function isPromoting(chess: Chess, from: Square, to: Square): boolean {
  if (!from) {
    return false;
  }

  const piece = chess.get(from);

  if (piece?.type !== 'p') {
    return false;
  }

  if (piece.color !== chess.turn()) {
    return false;
  }

  if (!['1', '8'].some((rank) => to.endsWith(rank))) {
    return false;
  }

  return chess
    .moves({ square: from, verbose: true })
    .map((it) => it.to)
    .includes(to);
}
