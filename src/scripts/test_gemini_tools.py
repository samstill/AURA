
import asyncio
import os
import logging
from dotenv import load_dotenv
import google.generativeai as genai
from google.generativeai.types import FunctionDeclaration, Tool

# Setup
logging.basicConfig(level=logging.INFO)
load_dotenv(".env")
api_key = os.getenv("GOOGLE_API_KEY")

if not api_key:
    print("Error: GOOGLE_API_KEY not found.")
    exit(1)

genai.configure(api_key=api_key)

# The Schema we are using
repo_tool_schema = {
    "type": "object",
    "properties": {
        "repo_name": {"type": "string", "description": "Repository name (e.g. project_aura)"}
    },
    "required": ["repo_name"]
}

# Wrap it
fd = FunctionDeclaration(
    name="search_github_repo",
    description="Search for and get status of a GitHub repository.",
    parameters=repo_tool_schema
)

model = genai.GenerativeModel(
    "models/gemini-2.5-flash",
    tools=[Tool(function_declarations=[fd])]
)

async def main():
    print("Starting Chat with Tools...")
    chat = model.start_chat()
    
    try:
        # Ask something that triggers the tool
        response = await chat.send_message_async("Check the status of project_aura repo")
        print(f"Response Parts: {response.parts}")
        
        # Check for function call
        for part in response.parts:
            if fn := part.function_call:
                print(f"SUCCESS: Tool Call Generated: {fn.name}({fn.args})")
                return

        print("Response Text:", response.text)

    except Exception as e:
        print(f"CRASH: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    asyncio.run(main())
