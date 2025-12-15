from services.router_service import router_service
import asyncio

async def test_classification():
    test_cases = [
        "hello",
        "Hello",
        "hello ",
        "what is 2+2",
        "tell me a joke",
        "book a meeting for tomorrow",
        "search for weather",
        "this is a very long message that should definitely be classified as smart because it exceeds five words"
    ]
    
    print(f"{'INPUT':<40} | {'PREDICTED':<10}")
    print("-" * 55)
    
    for text in test_cases:
        result = await router_service.classify(text)
        print(f"{text:<40} | {result:<10}")

if __name__ == "__main__":
    asyncio.run(test_classification())
