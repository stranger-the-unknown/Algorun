/// The game's numbers (L3, "safe whole numbers").
///
/// A number is a whole number from -[maxSafeNumber] to [maxSafeNumber]
/// (2^53 - 1). Inside that range the phone's 64-bit integers, a browser's
/// JavaScript numbers and Wasm integers are all exact, so a program computes
/// the same thing on every platform the game runs on. There are no
/// fractions, and a result outside the range is the run-time error "This
/// number is too big." everywhere, instead of wrapping on the phone and
/// rounding in a browser.
///
/// algorun-lang has the same model with the limit at 2^63 - 1 (its
/// deviations D2-D4), so a program that runs here without that error gives
/// the same answer there.
library;

/// The largest number the game counts with: 9 007 199 254 740 991.
const int maxSafeNumber = 9007199254740991;

/// Why [n] is not one of the game's numbers.
enum NumberProblem {
  /// It has a fractional part.
  fraction,

  /// It is outside +-[maxSafeNumber] (or not finite).
  tooBig,
}

/// Null when [n] is a number the game can hold.
NumberProblem? numberProblem(num n) {
  if (!n.isFinite) return NumberProblem.tooBig;
  if (n % 1 != 0) return NumberProblem.fraction;
  if (n > maxSafeNumber || n < -maxSafeNumber) return NumberProblem.tooBig;
  return null;
}

/// [n], which has no [numberProblem], in the one spelling every platform
/// agrees on: an `int` (a whole `2.0` from JSON becomes `2`), and never
/// JavaScript's negative zero.
int wholeNumber(num n) => n == 0 ? 0 : n.toInt();
