/* Author: Era Scarecrow
   Date:   14 August 2012
   Description: A simple Sudoku solver as a personal challenge. When optimized with the
     hardest puzzle supplied it did it in 12 seconds on a 3.2Ghz processor. The speed
     likely can be greatly increased if the results of the getBlock and getUsed are cached
     rather than all made from scratch.

   Hard: .....6....59.....82....8....45........3........6..3.54...325..6..................
*/

import std.stdio;
import std.exception;
import core.time;

alias int[9][9] Sudoku;
alias ubyte[10]  Used;  //0 is not used, and 1-9 are.
alias XY[9]     Block;  //For the square inner block
struct XY {
    int x,y;
}

///Simple exception removes the need to make a more complex struct, for brute force
class BrokenPuzzle : Exception {
    this(string msg) {
        super(msg);
    }
}

///for searching/handling inside squares only
///statically storing this can speed the result up
Block getBlockLocations(int x, int y) {
    //convert to [0 .. 3][0 .. 3] representation for whole blocks
    x = (x / 3) * 3;
    y = (y / 3) * 3;
    Block blk;
    foreach(i, ref element; blk) {
        element.x = x + (i % 3);
        element.y = y + (i / 3);
    }
    return blk;
}

unittest {
    Block at_1_1 = [{3,3},{4,3},{5,3},{3,4},{4,4},{5,4},{3,5},{4,5},{5,5}];
    Block at_2_0 = [{6,0},{7,0},{8,0},{6,1},{7,1},{8,1},{6,2},{7,2},{8,2}];
    
    writeln(getBlockLocations(4,4));
    writeln(getBlockLocations(8,1));
    
    assert(getBlockLocations(4,4) == at_1_1);
    assert(getBlockLocations(8,1) == at_2_0);
}

///three functions get the numbers used in a particular area. all along x, y, and the middle block. (Probably wrong word used)
Used getUsedColumn(ref const Sudoku puzzle, int x) {
    Used usedNumbers;
    foreach(y; 0 .. 9)
        usedNumbers[puzzle[x][y]] = true; //[0] ignored, so 1-9 actually mean something.
    return usedNumbers;
}

///
Used getUsedRow(ref const Sudoku puzzle, int y) {
    Used usedNumbers;
    foreach(x; 0 .. 9)
        usedNumbers[puzzle[x][y]] = true;
    return usedNumbers;
}

///
Used getUsedBlock(ref const Sudoku puzzle, int x, int y) {
    Block blk = getBlockLocations(x,y);
    Used usedNumbers;
    foreach(element; blk)
        usedNumbers[puzzle[element.x][element.y]] = true;
    return usedNumbers;
}

/// Will attempt to solve as many singles (only possible values) as possible
Sudoku solveSingles(Sudoku puzzle) {
    int changes;    //determines if it keeps the loop going
    
    do {
        changes = 0;
        foreach(y; 0 .. 9) {
            foreach(x; 0 .. 9) {
                //Only proceed if this spot is not filed in
                if (puzzle[x][y])
                    continue;

                int unusedCount;
                int unused;
                Used row = puzzle.getUsedRow(y);
                Used col = puzzle.getUsedColumn(x);
                Used blk = puzzle.getUsedBlock(x,y);

                debug {
                    writefln("\nAt x,y: %d,%d\n", x, y);
                    writeln("Row:         ", row);
                    writeln("Column:      ", col);
                    writeln("Inner Block: ", blk);
                }
                
                foreach(i; 1 .. 10) {
                    //all must be empty for it to be considered.
                    if ((row[i] | col[i] | blk[i]) == false) {
                        unused = i;
                        unusedCount++;
                    }
                }
                    
                //If only one, then it's the only possible choice.
                //If no unused one, the puzzle is currupt (see the continue at top)
                if (unusedCount == 1) {
                    puzzle[x][y] = unused;
                    changes++;
                    debug { puzzle.print(); }
                } else if (!unusedCount)
                    throw new BrokenPuzzle("Sudoku is corrupted and cannot be solved!");
            }
        }
    } while(changes);
    
    return puzzle;
}

///Forcibly guesses all possible combinations for a particular block.
Sudoku bruteForceSolve(const ref Sudoku puzzle) {
    foreach(y; 0 .. 9)
        foreach(x; 0 .. 9)
            if (!puzzle[x][y]) {
                Used row = puzzle.getUsedRow(y);
                Used col = puzzle.getUsedColumn(x);
                Used blk = puzzle.getUsedBlock(x,y);
            
                //work from the first 'possible' number and work our way up.
                foreach(i; 1 .. 10)
                    if ((row[i] | col[i] | blk[i]) == false) {
                        Sudoku bruteForcedPuzzle = cast(Sudoku) puzzle; //should be a copy as it's a fixed array size.
                        try {
                            bruteForcedPuzzle[x][y] = i;
                            return solve(bruteForcedPuzzle);
                        }
                        catch (BrokenPuzzle bp) { /*goes to the next one. Only currupted ones can get here*/ }
                    }

                //if we get this far, we failed.
                throw new BrokenPuzzle("Brute Force failed!");
            }
    
    return puzzle; //can only get here if it's already solved.
}

///
bool isSolved(ref const Sudoku puzzle) {
    foreach (row; puzzle)
        foreach (element; row)
            if (!element)
                return false;
    return true;
}

///
Sudoku solve(Sudoku puzzle) {
    while (!puzzle.isSolved()) {
        puzzle = puzzle.solveSingles();
        if (!puzzle.isSolved())
            puzzle = bruteForceSolve(puzzle);
    }
    return puzzle;
}

/// string to sudoku conversion. Takes all 81 characters in a row
Sudoku toSudoku(string str)
in {
    assert(str);
    assert(str.length == 81);
}
body {
    Sudoku puzzle;
    foreach(i, num; str) {
        if (num >= '0' && num <= '9')
            puzzle[i % 9][i / 9] = num - '0';
    }
    return puzzle;
}

void print(const ref Sudoku puzzle) {
    writeln();
    foreach(i; 0 .. 81) {
        char ch = cast(char)(puzzle[i % 9][i / 9] + '0');
        
        //adds appropriate newlines, and makes 0's periods instead.
        writef("%c%s", (ch == '0' ? '.' : ch), (i + 1) % 9 == 0 ? "\n" : "");
    }
    writeln();
}

int main(string[] argv) {
    if (argv.length == 1 || argv[1].length != 81) { 
        writefln("Used as: %s \"puzzle\"\n", argv[0]);
        writeln("  Where there's Puzzle, needs to be in numerical form from");
        writeln(" upper left to lower right. 0's or non numbers can be used as");
        writeln(" blanks, suggested periods or spaces.");
        return 1;   //bad input considered a error
    }
    
    Sudoku puzzle = toSudoku(argv[1]);
    
    print(puzzle);  //before
    
    //hope I'm doing the timing here right?
    TickDuration end, start;

        start = TickDuration.currSystemTick();
        puzzle = puzzle.solve();
        end = TickDuration.currSystemTick();
    
    print(puzzle);  //after
    
    writeln("Start: ", start);
    writeln("End:   ", end);
    writeln("Time:  ", end - start);
    return 0;
}