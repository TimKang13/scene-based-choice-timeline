from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional, List
from openai import OpenAI
import os
from dotenv import load_dotenv
from scene import Scene, Choice, State


# Load environment variables
load_dotenv()

app = FastAPI(title="DragonRuby LLM API", version="1.0.0")

# Configure OpenAI
client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))



class ChatRequest(BaseModel):
    input: str
    model: Optional[str] = "gpt-5-mini"
    effort: Optional[str] = "minimal"
    
    class Config:
        extra = "allow"  # Allow extra fields

    




@app.get("/")
async def root():
    return {"message": "DragonRuby LLM API is running!"}

@app.get("/test")
async def test():
    return {"status": "ok", "message": "API server is working"}

@app.post("/chat")
async def chat(request: ChatRequest):
    try:
        print(f"Received request: model={request.model}, input={request.input}, effort={request.effort}")
        
        response = client.responses.parse(
            model=request.model,
            input=request.input,
            reasoning={
                "effort": request.effort
            },
            text_format=Scene
        )

        result = {"response": response.output_text}
        print(f"Response: {result}")
        return result
    except Exception as e:
        print(f"Error: {str(e)}")
        raise HTTPException(status_code=500, detail=f"OpenAI API error: {str(e)}")

@app.post("/chat-debug")
async def chat_debug(request_data: dict):
    print(f"Raw request data: {request_data}")
    return {"debug": "received"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
