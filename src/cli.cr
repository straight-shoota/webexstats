require "./webexstats"

def from_utf16(byte_slice)
  String.from_utf16(Slice.new(byte_slice.to_unsafe.unsafe_as(Pointer(UInt16)), byte_slice.size // sizeof(UInt16)))
end

def to_utf16(utf16_slice)
  Slice.new(utf16_slice.to_unsafe.unsafe_as(Pointer(UInt8)), utf16_slice.size * sizeof(UInt16))
end

filename_in = ARGV[0]?
filename_out = ARGV[1]?

if filename_in
  filename_out ||= "#{filename_in.rchop(Path[filename_in].extension)}.csv"

  file = File.read(filename_in)

  content = from_utf16(file.to_slice)
else
  content = STDIN.gets_to_end
end

stats = Webexstats.new
stats.parse(content)

p! stats.questions

if filename_out
  File.open(filename_out, "w") do |file|
    byte_slice = to_utf16(stats.to_csv.to_utf16)

    file.write byte_slice
  end
else
  STDOUT << stats.to_csv
end
