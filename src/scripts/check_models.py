
import os
import asyncio
from openai import AsyncOpenAI
from dotenv import load_dotenv

# Load env from current dir (assuming running from project root)
load_dotenv(".env")

async def check_groq():
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        print("❌ SKIPPING GROQ: No API Key found in .env")
        return

    print(f"\n⚡ Checking GROQ Models (Key: {api_key[:5]}...):")
    try:
        client = AsyncOpenAI(
            api_key=api_key,
            base_url="https://api.groq.com/openai/v1"
        )
        models = await client.models.list()
        # Filter for likely "smart" or "reasoning" models
        print(f"   Found {len(models.data)} models.")
        for m in models.data:
            print(f"   - {m.id}")
            
    except Exception as e:
        print(f"❌ Groq Error: {e}")

async def check_openrouter():
    api_key = os.getenv("OPENROUTER_API_KEY")
    if not api_key:
        print("❌ SKIPPING OPENROUTER: No API Key found in .env")
        return

    print(f"\n⚡ Checking OPENROUTER Models (Key: {api_key[:5]}...):")
    try:
        client = AsyncOpenAI(
            api_key=api_key,
            base_url="https://openrouter.ai/api/v1"
        )
        # OpenRouter list might be huge, just print first few or search for specific ones
        models = await client.models.list()
        print(f"   Found {len(models.data)} models.")
        
        target_keywords = ["deepseek", "r1", "free"]
        print("   --- Matching 'DeepSeek / Free' ---")
        for m in models.data:
            if any(k in m.id.lower() for k in target_keywords):
                 # Check pricing if available via ID naming convention usually :free
                 print(f"   - {m.id}")

    except Exception as e:
        print(f"❌ OpenRouter Error: {e}")

async def main():
    await check_groq()
    await check_openrouter()

if __name__ == "__main__":
    asyncio.run(main())
