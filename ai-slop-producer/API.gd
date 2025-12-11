extends Node

var reply := ""

const GROQ_URL := "https://api.groq.com/openai/v1/chat/completions"
const API_KEY := ""

var model := "Llama-3.3-70B-Versatile"
var response := ""

var http: HTTPRequest

var tool_info = """
function name: example.
args: input (string).
required args: none.
returns: text that is "example text".
function description: this tool is an example tool that returns "example text" no matter what the args are.
usage conditions: use ONLY when the user asks to give an example of tool/function usage. DO NOT use this tool when told to use any other tool.
example usage: "tool" "example"
"args" user asked for tool example.
incorrect example usage:
"tool" "example tool call"
"args" give me an example tool call.
"""

# stores convo history
var messages: Array = []

func _ready():
	http = HTTPRequest.new()
	add_child(http)
	http.request_completed.connect(_on_request_completed)
	
	# add system prompt
	add_system_prompt("""
You are an AI model who has access to tools. Your job is to decide which tool to call based on the user's request, and provide a structured tool call rather than natural language when a tool is needed.
You must follow these rules:

Only call tools that are defined and available.

When calling a tool, output in this format:
!!!ToolCall
"tool" "<tool_name>"
"args" arg1, arg2
!!!
making sure to match the tool’s parameter schema. make sure to ONLY use this template and to wrap the tool call in "!!!". make sure to always give args for tools, even if the description says there is no args.
after you call the tool you will be told the result of the tool, this is not shown to the user but your reply is, if the result contains an error, attempt to fix it using the error message provided. 
If you need more information to make a correct tool call, ask the user for clarification.
Do NOT invent functions, arguments, or values that do not exist.
If no tool is appropriate, respond normally in text and do not say No tool is appropriate for this request.
Do not wrap tool calls in backticks or additional text.
When calling a tool, do not reply with any additional text when calling a tool.
Only call one tool at a time.
Your overall objective is to solve the user's request efficiently by choosing the correct tool and passing valid arguments.
tools: 

""")
	add_system_prompt(tool_info)

## ========= CONVERSATION HANDLING ========= ##

func add_system_prompt(text: String):
	messages.append({
		"role": "system",
		"content": text
	})

func send_user_message(text: String):
	messages.append({
		"role": "user",
		"content": text
	})

	make_request()


## ========= HTTP REQUEST ========= ##

func make_request():
	var headers = [
		"Content-Type: application/json",
		"Authorization: " + "Bearer %s" % API_KEY
	]

	var body = {
		"model": model,
		"messages": messages
	}

	var json := JSON.stringify(body)
	http.request(GROQ_URL, headers, HTTPClient.METHOD_POST, json)


func _on_request_completed(result, code, headers, body):
	if code != 200:
		print("Groq error:", code, "result:", result)
		return

	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		print("JSON parse fail")
		return

	var msg = data.get("choices", [])[0].get("message", {}).get("content", "")
	response = msg
	if response != "":
		var func_ret = parse_response(response)
		if func_ret == null:
			reply = response
		else:
			send_user_message("tool returned: " + func_ret) 
		response = ""

	# store AI reply into history
	messages.append({
		"role": "assistant",
		"content": msg
	})


## ========= PRINT REPLIES ========= ##
func parse_response(response):
	var err = ""
	if response.substr(0, 11) == "!!!ToolCall":
		var response_block = response.substr(12, response.length() - 15) #12 + 3 cuz !!!
		
		var tool
		var args
		if response_block.substr(0, 6) == "\"tool\"":
			tool = response_block.substr(8, response_block.find("\n", 8) - 9)
			
			if response_block.substr(response_block.find("\n", 8) + 1, 6) == "\"args\"":
				args = response_block.substr(response_block.find("\n", 8) + 8, response_block.length() - (response_block.find("\n", 8) + 3))
				
			else:
				err = "incorrect tool syntax: args keyword not found"
				print("sum ting wong")
				print(response_block.substr(response_block.find("\n", 8) - 7, 6))
				return err 
		else: 
			err = "incorrect tool syntax: tool keyword not found"
			return err
		
		
		if tool == "example":
			return example(args)
		else:
			err = "tool not found: " + tool
			return err
	else:
		return

func send_message(message):
	send_user_message(message)
	

func example(arg):
	print("ai says: ", arg)
	return "example text"
