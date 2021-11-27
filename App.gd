extends Control

var questions = []
var availableQuestions = []
var alphabet := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
var rng := RandomNumberGenerator.new()

export var QuestionPanel: NodePath
export var Scoreboard: NodePath
export var MultipleChoiceAnswerRes: PackedScene
export var DropDownAnswerRes: PackedScene

var currentQuestion
var currentQuestionIndex
var questionPanel
var scoreboard
var correctNode
var totalNode
var scoreNode
var percentNode

func _ready():
	rng.randomize()
	
	load_questions()
	
	next_question()
	
	scoreboard = get_node(Scoreboard)
	correctNode = scoreboard.get_node("MarginContainer/NumberCorrect/Correct")
	totalNode = scoreboard.get_node("MarginContainer/NumberCorrect/Total")
	scoreNode = scoreboard.get_node("MarginContainer/Score/Number")
	percentNode = scoreboard.get_node("MarginContainer/PercentCorrect/Number")
	
	correctNode.text = "0"
	totalNode.text = "0"
	scoreNode.text = "0"
	percentNode.text = "0%"

func load_questions():
	var file := File.new()
	file.open("Questions.txt", File.READ)
	while file.get_position() < file.get_len():
		var lines = []
		var line: String = file.get_line()
		while(!line.lstrip(" \t\n").empty()):
			lines.append(line)
			line = file.get_line()
		questions.append(load_question(lines))
	
	for i in range(questions.size()):
		availableQuestions.append(i)

func load_question(lines: Array):
	var type = to_question_type(lines[0])
	match (type):
		QuestionType.MultipleChoice:
			var text = lines[1].replace("\\n", "\n")
			var answers = []
			for i in range(2, lines.size()):
				var line = lines[i]
				var answer = MultipleChoiceAnswer.new(line.trim_prefix("#C:"), line.begins_with("#C:"))
				answers.append(answer)
			return MultipleChoiceQuestion.new(type, text, answers)
		QuestionType.DropDown:
			var text = lines[1].replace("\\n", "\n")
			var answers := []
			var options := []
			for i in range(2, lines.size()):
				var line = lines[i]
				if line.begins_with("#O:"):
					options.append(line.trim_prefix("#O:"))
				elif line.begins_with("#"):
					var cutoff = line.find(":")
					var optIdx := int(line.substr(0, cutoff + 1))
					var ansText = line.substr(cutoff + 1)
					answers.append(DropDownAnswer.new(ansText, optIdx))
			return DropDownQuestion.new(type, text, answers, options)
		QuestionType.Invalid:
			pass

func to_question_type(input):
	match (input.rstrip(" \t")):
		"Multiple Choice":
			return QuestionType.MultipleChoice
		"Drop Down":
			return QuestionType.DropDown
		_:
			push_error("Parsed question with incorrect type!")
			return QuestionType.Invalid

func get_answer_index():
	var answers = questionPanel.get_node("ScrollContainer/Contents/MarginContainer/Answers").get_children()
	var i = 0
	for ans in answers:
		if (ans.get_node("Button").pressed):
			return i
		i += 1

func submit_button_callback():	
	match (currentQuestion.Type):
		QuestionType.MultipleChoice:
			var answers = $Panel/VBoxContainer/QuestionPanel/ScrollContainer/Contents/MarginContainer/Answers
			for a in answers.get_children():
				a.get_node("Button").disabled = true
			var answered = get_answer_index()
			if answered == null:
				return
			var answer = answers.get_child(answered)
			if (currentQuestion.Answers[answered].Correct):
				question_correct()
				answer.get_node("Checkmark").show()
			else:
				question_incorrect()
				answer.get_node("XMark").show()
				for i in range(answers.get_children().size()):
					if currentQuestion.Answers[i].Correct:
						answers.get_child(i).get_node("Checkmark").show()
			
			$Panel/VBoxContainer/NextButton.show()
			$Panel/VBoxContainer/SubmitButton.hide()
		QuestionType.DropDown:
			var answers = questionPanel.get_node("ScrollContainer/Contents/MarginContainer/Answers").get_children()
			for a in answers:
				a.get_node("HBox/OptionButton").disabled = true
			var correct = true
			var i = 0
			for ans in answers:
				if ans.get_node("HBox/OptionButton").selected != currentQuestion.Answers[i].Option:
					correct = false
					ans.get_node("HBox/XMark").show()
				else:
					ans.get_node("HBox/Checkmark").show()
				i += 1
			
			if correct:
				question_correct()
			else:
				question_incorrect()
			
			$Panel/VBoxContainer/NextButton.show()
			$Panel/VBoxContainer/SubmitButton.hide()

func question_correct():
	var correct = int(correctNode.text)
	var total = int(totalNode.text)
	var score = int(scoreNode.text)
	
	correct += 1
	total += 1
	score += 100
	var percent := float(correct) / float(total)
	var percent_string
	if (percent == 1):
		percent_string = "100%"
	else:
		percent_string = String(int((percent - int(percent)) * 100)) + "%"
	
	correctNode.text = String(correct)
	totalNode.text = String(total)
	scoreNode.text = String(score)
	percentNode.text = percent_string

func question_incorrect():
	var correct = int(correctNode.text)
	var total = int(totalNode.text)
	
	total += 1
	var percent := float(correct) / float(total)
	var percent_string
	if (percent == 1):
		percent_string = "100%"
	else:
		percent_string = String(int((percent - int(percent)) * 100)) + "%"
	
	totalNode.text = String(total)
	percentNode.text = percent_string
	
	availableQuestions.append(currentQuestionIndex)

func next_button_callback():
	next_question()

func next_question():
	questionPanel = get_node(QuestionPanel)
	var answersNode = questionPanel.get_node("ScrollContainer/Contents/MarginContainer/Answers")
	for child in answersNode.get_children():
		child.queue_free()
	
	if (availableQuestions.empty()):
		for i in range(questions.size()):
			availableQuestions.append(i)
	
	var next = rng.randi_range(0, availableQuestions.size() - 1)
	var next_index = availableQuestions[next]
	availableQuestions.remove(next)
	currentQuestionIndex = next_index
	
	currentQuestion = questions[next_index]
	
	var questionLabel = questionPanel.get_node("ScrollContainer/Contents/Question/QuestionText/Container/QuestionLabel")
	questionLabel.text = currentQuestion.Text
	
	var questionNumber = questionPanel.get_node("ScrollContainer/Contents/Question/QuestionNumber/NumberLabel")
	questionNumber.text = String(next_index + 1) + ")."
	
	var group = ButtonGroup.new()
	match (currentQuestion.Type):
		QuestionType.MultipleChoice:
			for i in range(currentQuestion.Answers.size()):
				var answer = MultipleChoiceAnswerRes.instance()
				answer.get_node("Text").text = currentQuestion.Answers[i].Text
				answer.get_node("Letter").text = alphabet[i] + ")."
				answer.get_node("Button").group = group
				answersNode.add_child(answer)
		QuestionType.DropDown:
			for i in range(currentQuestion.Answers.size()):
				var answer = DropDownAnswerRes.instance()
				answer.get_node("HBox/Letter").text = alphabet[i] + ")."
				answer.get_node("HBox/Text").text = currentQuestion.Answers[i].Text
				for option in currentQuestion.Options:
					answer.get_node("HBox/OptionButton").add_item(option)
				answersNode.add_child(answer)
	
	$Panel/VBoxContainer/NextButton.hide()
	$Panel/VBoxContainer/SubmitButton.show()



enum QuestionType {
	Invalid
	MultipleChoice
	DropDown
}

class MultipleChoiceAnswer:
	var Text := ""
	var Correct := false
	
	func _init(text, correct):
		self.Text = text
		self.Correct = correct

class MultipleChoiceQuestion:
	var Type = QuestionType.MultipleChoice
	var Text := ""
	var Answers := []
	
	func _init(type, text, answers):
		self.Type = type
		self.Text = text
		self.Answers = answers

class DropDownAnswer:
	var Text := ""
	var Option := -1
	
	func _init(text, option):
		self.Text = text
		self.Option = option

class DropDownQuestion:
	var Type = QuestionType.DropDown
	var Text := ""
	var Answers := []
	var Options := []
	
	func _init(type, text, answers, options):
		self.Type = type
		self.Text = text
		self.Answers = answers
		self.Options = options
