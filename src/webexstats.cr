require "csv"

class Webexstats
  @current_question : Question? = nil
  getter questions = Array(Question).new

  @expecting_answers = true

  def parse(txt)
    txt.each_line do |line|
      parse_line line
    end
  end

  def parse_line(line)
    first_char = line[0]?

    if first_char === 0xFEFF # BOM
      line = line[1..]
      first_char = line[0]?
    end

    case first_char
    when Nil
      # empty line

      if @expecting_answers
        @expecting_answers = false
      else
        @current_question = nil
      end
    when .ascii_number?
      # new question
      questions << (@current_question = parse_question(line))
      @expecting_answers = true
    when ' '
      if question = @current_question
        if @expecting_answers
          # answer
          question.answers << parse_answer(line)
        else
          # voting matrix
          line = line.strip
          if line.ends_with?("|")
            question.votes << parse_vote(line)
          end
        end
      end
    when .letter?
      # "Keine Antwort"
      if question = @current_question
        question.answers << parse_answer(line)
      end
    else
      p! first_char.ord.to_s(16)
    end
  end

  record Question,
    number : Int32,
    label : String,
    answers = Array(Answer).new,
    votes = Array(Vote).new

  record Answer,
    letter : String,
    label : String,
    count : Int32,
    total : Int32,
    percent : Int32

  record Vote,
    label : String,
    results : Array(String)

  def parse_question(line)
    number, _, label = line.partition(".")
    Question.new(number.to_i, label)
  end

  def parse_answer(line)
    percent = line[-5...-2]

    numbers_index = line.rindex(" ", -8)
    numbers = line[numbers_index..-8]
    count, _, total = numbers.partition("/")

    letter_and_label = line[0...numbers_index].strip
    letter, _, label = letter_and_label.partition(".")
    if label.empty?
      label = letter
      letter = ""
    end
    Answer.new(letter, label, count.to_i, total.to_i, percent.to_i)
  end

  def parse_vote(line)
    fields = line[0..-2].split(" | ")
    label = fields.shift

    Vote.new(label, fields)
  end

  def to_csv
    CSV.build(separator: ';') do |builder|
      builder.row "", "Frage/Antwort", "Anzahl absolut", "Prozent"
      questions.each do |question|
        builder.row question.number, question.label, question.votes.size, "100%"
        question.answers.each do |answer|
          builder.row answer.letter, answer.label, answer.count, "#{answer.percent}%"
        end
        builder.row
        builder.row do |row|
          row << "Teilnehmer"
          question.answers.each do |answer|
            row << answer.letter
          end
        end
        question.votes.each do |vote|
          builder.row do |row|
            row << vote.label
            row.concat vote.results
          end
        end
        builder.row
      end
    end
  end
end
