import gradio as gr

def chat_function(message, history):
    """
    Handle chat messages - this is where newsletter generation logic will go
    """
    # For now, just echo back a placeholder response
    response = f"Thanks for your message: '{message}'. Newsletter generation features coming soon!"

    # Add the new conversation to history
    history.append((message, response))
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
