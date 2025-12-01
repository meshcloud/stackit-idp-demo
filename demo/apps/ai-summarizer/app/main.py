# ========================================================================
# demo/apps/ai-summarizer/app/main.py
# ========================================================================
from fastapi import FastAPI, HTTPException
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import traceback
import sys


from .stackit_client import summarize_text


app = FastAPI(title="STACKIT AI Summarizer Demo")

# Mount the static directory to serve the simple web UI
app.mount("/static", StaticFiles(directory="static"), name="static")


class SummarizeRequest(BaseModel):
    # Request body for the /summarize endpoint
    text: str


@app.get("/")
async def index():
    """
    Serve the main HTML page for the demo UI.
    """
    return FileResponse("static/index.html")


@app.post("/summarize")
async def summarize(req: SummarizeRequest):
    """
    Summarize the given text using the STACKIT AI model and return JSON.
    """
    try:
        # Run the blocking summarize_text function in a threadpool
        summary = await run_in_threadpool(summarize_text, req.text)
        return {"summary": summary}
    except Exception as exc:
        traceback.print_exc(file=sys.stderr)
        raise HTTPException(status_code=500, detail=str(exc)) from exc
