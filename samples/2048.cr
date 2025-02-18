# Based on 2048 by Gabriele Cirulli - gabrielecirulli.github.io/2048

require "colorize"

enum Action
  Up
  Down
  Left
  Right
  Escape
  Unknown
end

module Screen
  TILES = {
        0 => {Colorize::ColorANSI::White, nil},
        2 => {Colorize::ColorANSI::Black, Colorize::ColorANSI::White},
        4 => {Colorize::ColorANSI::Blue, Colorize::ColorANSI::White},
        8 => {Colorize::ColorANSI::Black, Colorize::ColorANSI::Yellow},
       16 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Red},
       32 => {Colorize::ColorANSI::Black, Colorize::ColorANSI::Red},
       64 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Magenta},
      128 => {Colorize::ColorANSI::Red, Colorize::ColorANSI::Yellow},
      256 => {Colorize::ColorANSI::Magenta, Colorize::ColorANSI::Yellow},
      512 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Yellow},
     1024 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Yellow},
     2048 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Yellow},
     4096 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Black},
     8192 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Black},
    16384 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Black},
    32768 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Black},
    65536 => {Colorize::ColorANSI::White, Colorize::ColorANSI::Black},
  }

  def self.colorize_for(tile)
    fg_color, bg_color = TILES[tile]
    color = Colorize.with.fore(fg_color)
    color = color.back(bg_color) if bg_color
    color.surround do
      yield
    end
  end

  def self.clear
    print "\e[2J\e[1;1H"
  end

  def self.read_keypress
    STDIN.raw do |io|
      buffer = Bytes.new(3)
      bytes_read = io.read(buffer)
      return Action::Unknown if bytes_read == 0
      input = String.new(buffer[0, bytes_read])

      case input
      when "\e[A", "w"
        Action::Up
      when "\e[B", "s"
        Action::Down
      when "\e[C", "d"
        Action::Right
      when "\e[D", "a"
        Action::Left
      when "\e", "\u{3}", "q", "Q"
        Action::Escape
      else
        Action::Unknown
      end
    end
  end
end

class Drawer
  INNER_CELL_WIDTH  = 16
  INNER_CELL_HEIGHT =  6

  def initialize
    @n = 0
    @grid = [] of Array(String)
    @current_row = [] of String
    @content_line = false
  end

  def set_current_row(row)
    @current_row = row
  end

  def draw(grid)
    @grid = grid
    @n = @grid.size

    Screen.clear
    box
  end

  def box
    top_border

    (@n - 1).times do |row|
      tile row
      mid_border
    end

    tile @n - 1

    bottom_border
  end

  def tile(row)
    set_current_row @grid[row]

    INNER_CELL_HEIGHT.times do |i|
      if i == (@n / 2) + 1
        content_line
      else
        space_line
      end
    end

    set_current_row [] of String
  end

  def space_line
    line '│', " ", '│', '│'
  end

  def content_line
    @content_line = true
    space_line
    @content_line = false
  end

  def top_border
    line '┌', "─", '┬', '┐'
  end

  def mid_border
    line '├', "─", '┼', '┤'
  end

  def bottom_border
    line '└', "─", '┴', '┘'
  end

  def line(left, fill, inner, right)
    print left

    (@n - 1).times do |cell|
      cell_line fill, cell

      print inner
    end

    cell_line fill, @n - 1

    puts right
  end

  def cell_line(fill, cell)
    content = @current_row.fetch(cell) { "empty" }
    tile_value = (content == "empty" ? 0 : (content.to_i? || 0)).to_i
    content = "" if !@content_line || content == "empty"

    fill_size = INNER_CELL_WIDTH // 2
    fill_size -= content.size // 2
    fill_size -= 2

    print fill

    Screen.colorize_for(tile_value) do
      print fill*fill_size
      print content
      print fill*fill_size
      print fill if content.size % 2 == 0
    end
    print fill
  end
end

class Game
  def initialize
    @drawer = Drawer.new
    @grid = [
      [nil, nil, nil, nil] of Int32?,
      [nil, nil, nil, nil] of Int32?,
      [nil, nil, nil, nil] of Int32?,
      [nil, nil, nil, nil] of Int32?,
    ]

    insert_tile
    insert_tile
  end

  def run
    draw

    until won? || lost?
      if execute_action read_action
        insert_tile
        draw
      end
    end

    if won?
      end_game "You won!"
    elsif lost?
      end_game "You lost!"
    else
      raise "Game loop quit unexpectedly"
    end
  end

  def draw
    @drawer.draw drawable_grid
  end

  def drawable_grid
    @grid.map &.map(&.to_s)
  end

  def read_action
    Screen.read_keypress
  end

  def insert_tile
    value = rand > 0.8 ? 4 : 2

    empty_cells = @grid.map(&.count &.nil?).sum

    fill_cell = empty_cells > 1 ? rand(empty_cells - 1) + 1 : 1

    empty_cell_count = 0

    each_cell_with_index do |tile, row, col|
      empty_cell_count += 1 unless tile

      if empty_cell_count == fill_cell
        @grid[row][col] = value
        return
      end
    end
  end

  def each_cell_with_index
    0.upto(@grid.size - 1) do |row|
      0.upto(@grid.size - 1) do |col|
        yield @grid[row][col], row, col
      end
    end
  end

  def execute_action(action)
    case action
    in .up?, .down?, .left?, .right?
      if can_move_in? action
        shift_grid action
        true
      else
        false
      end
    in .escape?
      end_game "Bye"
    in .unknown?
      false # ignore
    end
  end

  def shift_grid(direction)
    drow, dcol = offsets_for direction
    shift_tiles_to_empty_cells direction, drow, dcol
    merge_tiles direction, drow, dcol
    shift_tiles_to_empty_cells direction, drow, dcol
  end

  def shift_tiles_to_empty_cells(direction, drow, dcol)
    modified = true
    while modified
      modified = false
      movable_tiles(direction, drow, dcol) do |tile, row, col|
        unless @grid[row + drow][col + dcol]
          @grid[row + drow][col + dcol] = tile
          @grid[row][col] = nil
          modified = true
        end
      end
    end
  end

  def merge_tiles(direction, drow, dcol)
    movable_tiles(direction, drow, dcol) do |tile, row, col|
      if @grid[row + drow][col + dcol] == tile
        @grid[row][col] = nil
        @grid[row + drow][col + dcol] = tile*2
      end
    end
  end

  def movable_tiles(direction, drow, dcol)
    max = @grid.size - 1
    from_row, to_row, from_column, to_column =
      case direction
      when .up?, .left?
        {0, max, 0, max}
      when .down?, .right?
        {max, 0, max, 0}
      else
        raise ArgumentError.new "Unknown direction #{direction}"
      end
    from_row.to(to_row) do |row|
      from_column.to(to_column) do |col|
        tile = @grid[row][col]
        if tile && !to_border?(direction, row, col, drow, dcol)
          yield tile, row, col
        end
      end
    end
  end

  def can_move_in?(direction)
    drow, dcol = offsets_for direction

    movable_tiles(direction, drow, dcol) do |tile, row, col|
      target_tile = @grid[row + drow][col + dcol]
      return true if !target_tile || target_tile == tile
    end

    false
  end

  def offsets_for(direction)
    drow = dcol = 0

    case direction
    when .up?
      drow = -1
    when .down?
      drow = 1
    when .left?
      dcol = -1
    when .right?
      dcol = 1
    else
      raise ArgumentError.new "Unknown direction #{direction}"
    end

    {drow, dcol}
  end

  def to_border?(direction, row, col, drow, dcol)
    case direction
    when .up?
      row + drow < 0
    when .down?
      row + drow >= @grid.size
    when .left?
      col + dcol < 0
    when .right?
      col + dcol >= @grid.size
    else
      false
    end
  end

  def won?
    @grid.any? &.any?(&.==(2048))
  end

  def lost?
    !can_move?
  end

  def can_move?
    can_move_in?(Action::Up) || can_move_in?(Action::Down) ||
      can_move_in?(Action::Left) || can_move_in?(Action::Right)
  end

  def end_game(msg)
    puts msg
    exit
  end
end

at_exit { STDIN.cooked! }
Game.new.run
