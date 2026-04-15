'use client';

import { useState, useRef, useEffect } from 'react';
import { Send, User } from 'lucide-react';
import Image from 'next/image';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: Date;
}

export default function Twin() {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  const [sessionId, setSessionId] = useState<string>('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const sendMessage = async () => {
    if (!input.trim() || isLoading) return;

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content: input,
      timestamp: new Date(),
    };

    setMessages(prev => [...prev, userMessage]);
    setInput('');
    setIsLoading(true);

    try {
      const response = await fetch(`${process.env.NEXT_PUBLIC_API_URL}/chat`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          message: input,
          session_id: sessionId || undefined,
        }),
      });

      if (!response.ok) throw new Error('Failed to send message');

      const data = await response.json();

      if (!sessionId) {
        setSessionId(data.session_id);
      }

      const assistantMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: data.response,
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, assistantMessage]);
    } catch (error) {
      console.error(error);

      const errorMessage: Message = {
        id: (Date.now() + 1).toString(),
        role: 'assistant',
        content: 'Sorry, I encountered an error. Please try again.',
        timestamp: new Date(),
      };

      setMessages(prev => [...prev, errorMessage]);
    } finally {
      setIsLoading(false);
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      sendMessage();
    }
  };

  return (
    <div className="flex flex-col h-full bg-white rounded-2xl">
      
      {/* Header */}
      <div className="bg-gradient-to-r from-purple-600 via-purple-700 to-indigo-600 text-white p-4 rounded-t-2xl">
        <h2 className="text-xl font-semibold flex items-center gap-2">
          <Image
            src="/profile_image.jpg"
            alt="Steve"
            width={24}
            height={24}
            className="rounded-full object-cover border border-white/30"
          />
          Steve's (AI Twin)
        </h2>
        <p className="text-sm text-purple-100 mt-1">
          Your AI Digital assistant
        </p>
      </div>

      {/* Messages */}
      <div className="flex-1 overflow-y-auto p-4 space-y-4 relative">
        
        {/* Scroll fade */}
        <div className="absolute top-0 left-0 right-0 h-6 bg-gradient-to-b from-white to-transparent pointer-events-none" />

        {messages.length === 0 && (
          <div className="text-center text-purple-500 mt-8">
            <Image
              src="/profile_image.jpg"
              alt="Steve"
              width={48}
              height={48}
              className="mx-auto mb-3 rounded-full object-cover border-2 border-purple-200 shadow-md shadow-purple-200/50"
            />
            <p>Hello! I&apos;m Steve's Digital Twin.</p>
            <p className="text-sm mt-2">Ask me anything about my career!</p>
          </div>
        )}

        {messages.map((message) => (
          <div
            key={message.id}
            className={`flex gap-3 ${
              message.role === 'user' ? 'justify-end' : 'justify-start'
            }`}
          >
            {/* Assistant avatar (YOU) */}
            {message.role === 'assistant' && (
              <div className="flex-shrink-0">
                <Image
                  src="/profile_image.jpg"
                  alt="Steve"
                  width={32}
                  height={32}
                  className="rounded-full object-cover border border-purple-200 shadow-sm"
                />
              </div>
            )}

            {/* Message bubble */}
            <div
              className={`max-w-[70%] rounded-2xl p-3 ${
                message.role === 'user'
                  ? 'bg-purple-600 text-white'
                  : 'bg-white border border-purple-100 text-purple-900'
              }`}
            >
              <p className="whitespace-pre-wrap">{message.content}</p>
              <p
                className={`text-xs mt-1 ${
                  message.role === 'user'
                    ? 'text-purple-200'
                    : 'text-purple-400'
                }`}
              >
                {message.timestamp.toLocaleTimeString()}
              </p>
            </div>

            {/* User avatar */}
            {message.role === 'user' && (
              <div className="flex-shrink-0">
                <div className="w-8 h-8 bg-indigo-500 rounded-full flex items-center justify-center">
                  <User className="w-5 h-5 text-white" />
                </div>
              </div>
            )}
          </div>
        ))}

        {/* Loading state */}
        {isLoading && (
          <div className="flex gap-3 justify-start">
            <div className="flex-shrink-0">
                <img
      src="/profile_image.jpg"
      alt="Steve"
      width={32}
      height={32}
      className="rounded-full object-cover border border-purple-200 shadow-sm"
    />
            </div>
            <div className="bg-white border border-purple-100 rounded-lg p-3">
              <div className="flex space-x-2">
                <div className="w-2 h-2 bg-purple-400 rounded-full animate-bounce" />
                <div className="w-2 h-2 bg-purple-400 rounded-full animate-bounce delay-100" />
                <div className="w-2 h-2 bg-purple-400 rounded-full animate-bounce delay-200" />
              </div>
            </div>
          </div>
        )}

        <div ref={messagesEndRef} />
      </div>

      {/* Input */}
      <div className="border-t border-purple-100 p-4 bg-white rounded-b-2xl">
        <div className="flex gap-2">
          <input
            type="text"
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyPress}
            placeholder="Ask me about my experience, skills, or projects..."
            className="flex-1 px-4 py-2 border border-purple-200 rounded-lg focus:outline-none focus:ring-2 focus:ring-purple-500 focus:border-transparent text-purple-900 placeholder-purple-400"
            disabled={isLoading}
          />
          <button
            onClick={sendMessage}
            disabled={!input.trim() || isLoading}
            className="px-4 py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 focus:outline-none focus:ring-2 focus:ring-purple-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
          >
            <Send className="w-5 h-5" />
          </button>
        </div>
      </div>
    </div>
  );
}