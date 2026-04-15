import Twin from '@/components/twin';

export default function Home() {
  return (
    <main className="min-h-screen bg-gradient-to-br from-purple-50 via-slate-50 to-purple-100">
      <div className="container mx-auto px-4 py-8 relative">
        
        {/* Subtle background glow */}
        <div className="absolute inset-0 bg-purple-300/10 blur-3xl -z-10" />

        <div className="max-w-4xl mx-auto">
          
          <h1 className="text-4xl font-bold text-center bg-gradient-to-r from-purple-600 to-indigo-600 bg-clip-text text-transparent mb-2">
            Digital Twin
          </h1>

          <p className="text-center text-purple-600/80 mb-8">
            Let's have a Conversation about my Career
          </p>

          <div className="h-[600px] rounded-2xl border border-purple-100/80 bg-white shadow-2xl shadow-purple-200/40">
            <Twin />
          </div>

          <footer className="mt-8 text-center text-sm text-purple-500">
            <p>@Copyright 2025</p>
          </footer>

        </div>
      </div>
    </main>
  );
}