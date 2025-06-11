import gradio as gr
import requests
import json

LLAMA_SERVER_URL = "http://localhost:8080/v1/chat/completions"

def chat_function(message, history):
    """
    Handle chat messages using llama-server
    """
    try:
        # Prepare the conversation history for the API
        messages = []
        
        # Add system message for newsletter context
        messages.append({
            "role": "system",
            "content": "You are a helpful assistant specialized in creating engaging company newsletters. Help users write newsletter content, generate ideas, create headlines, and provide formatting suggestions. Be creative, professional, and focus on making content that employees will actually want to read."
        })
        
        # Add conversation history
        for user_msg, assistant_msg in history:
            messages.append({"role": "user", "content": user_msg})
            messages.append({"role": "assistant", "content": assistant_msg})
        
        # Add current message
        messages.append({"role": "user", "content": message})
        
        # API request payload
        payload = {
            "model": "llama",  # This might need to match your model name
            "messages": messages,
            "temperature": 0.7,
            "max_tokens": 1000,
            "stream": False
        }
        
        # Make request to llama-server
        response = requests.post(
            LLAMA_SERVER_URL,
            headers={"Content-Type": "application/json"},
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            result = response.json()
            bot_response = result["choices"][0]["message"]["content"]
        else:
            bot_response = f"Error: Server returned status {response.status_code}. Make sure llama-server is running on port 8080."
            
    except requests.exceptions.ConnectionError:
        bot_response = "Error: Cannot connect to llama-server. Please make sure it's running on http://localhost:8080"
    except requests.exceptions.Timeout:
        bot_response = "Error: Request timed out. The model might be taking too long to respond."
    except Exception as e:
        bot_response = f"Error: {str(e)}"
    
    # Add the new conversation to history
    history.append((message, bot_response))
    return history

def create_newsletter_chat():
    """
    Create the main chat interface
    """
    
    # Create the interface
    with gr.Blocks(title="Newsletter Generator") as demo:
        
        # Welcome header
        gr.Markdown("""
        # 📰 Newsletter Generator
        
        **Create engaging company newsletters with AI assistance**
        """)

        # Instructions in columns
        with gr.Row():
            with gr.Column():
                gr.Markdown("""
                ### How to use:
                - Describe what you want to include in your newsletter
                - Specify the tone, audience, or specific topics
                - Ask for content ideas, headlines, or full newsletter sections
                - Request formatting help or layout suggestions
                """)
            
            with gr.Column():
                gr.Markdown("""
                ### Example prompts:
                - "Create a newsletter about our Q1 achievements"
                - "Write a fun announcement about our new office dog"
                - "Generate ideas for our monthly team spotlight section"
                """)
        
        # Chat interface
        chatbot = gr.Chatbot(
            height=400,
            placeholder="Your newsletter assistant is ready to help! Ask me anything about creating engaging company content.",
            show_label=False
        )
        
        # Input components
        with gr.Row():
            msg = gr.Textbox(
                placeholder="Tell me what you'd like to include in your newsletter...",
                container=False,
                scale=4
            )
            submit = gr.Button("Send", variant="primary", scale=1)
        
        # Clear button
        clear = gr.Button("Clear Chat", variant="secondary", size="sm")
        
        # Event handlers
        msg.submit(chat_function, inputs=[msg, chatbot], outputs=[chatbot])
        submit.click(chat_function, inputs=[msg, chatbot], outputs=[chatbot])
        msg.submit(lambda: "", outputs=[msg])
        submit.click(lambda: "", outputs=[msg])
        clear.click(lambda: [], outputs=[chatbot])
    
    return demo

if __name__ == "__main__":
    # Create and launch the app
    app = create_newsletter_chat()
    app.launch(
        server_name="0.0.0.0",  # Allow external connections
        server_port=7860,       # Default Gradio port
        share=True,            # Set to True to create a public link
        debug=True              # Enable debug mode during development
    )
