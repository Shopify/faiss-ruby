#!/usr/bin/env ruby

require "bundler/setup"
require "faiss"
require "benchmark"
require "numo/narray"

# Parameters
DIMENSIONS = 128
NUM_VECTORS = 10_000
NUM_QUERIES = 1_000
NUM_THREADS = 4
K_NEIGHBORS = 10

puts "GVL Release Benchmark for Faiss Index"
puts "=" * 50
puts "Configuration:"
puts "  Dimensions: #{DIMENSIONS}"
puts "  Index vectors: #{NUM_VECTORS}"
puts "  Query vectors: #{NUM_QUERIES}"
puts "  Threads: #{NUM_THREADS}"
puts "  K neighbors: #{K_NEIGHBORS}"
puts

# Generate random data
print "Generating random data..."
train_data = Numo::SFloat.new(NUM_VECTORS, DIMENSIONS).rand
query_data = Numo::SFloat.new(NUM_QUERIES, DIMENSIONS).rand
puts " done!"

# Create and train index
print "Creating and training index..."
index = Faiss::IndexFlatL2.new(DIMENSIONS)
index.add(train_data)
puts " done! (#{index.ntotal} vectors in index)"
puts

# Helper method to perform searches
def perform_searches(index, queries, iterations = 1)
  iterations.times do
    queries.shape[0].times do |i|
      query = queries[i, true].reshape(1, queries.shape[1])
      index.search(query, K_NEIGHBORS)
    end
  end
end

# Split queries for parallel processing
queries_per_thread = query_data.shape[0] / NUM_THREADS
thread_queries = NUM_THREADS.times.map do |i|
  start_idx = i * queries_per_thread
  end_idx = (i + 1) * queries_per_thread
  query_data[start_idx...end_idx, true]
end

puts "Benchmark Results:"
puts "-" * 50

# 1. Single-threaded baseline
puts "\n1. Single-threaded baseline:"
single_time = Benchmark.realtime do
  perform_searches(index, query_data)
end
puts "   Time: #{single_time.round(3)}s"
puts "   Queries/sec: #{(NUM_QUERIES / single_time).round(2)}"

# 2. Multi-threaded with regular (unfrozen) index
puts "\n2. Multi-threaded with UNFROZEN index (GVL not released):"
unfrozen_time = Benchmark.realtime do
  threads = thread_queries.map do |queries|
    Thread.new { perform_searches(index, queries) }
  end
  threads.each(&:join)
end
puts "   Time: #{unfrozen_time.round(3)}s"
puts "   Queries/sec: #{(NUM_QUERIES / unfrozen_time).round(2)}"
puts "   Speedup vs single-threaded: #{(single_time / unfrozen_time).round(2)}x"

# 3. Multi-threaded with frozen index
puts "\n3. Multi-threaded with FROZEN index (GVL released):"
index.freeze  # Freeze the index to enable GVL release
frozen_time = Benchmark.realtime do
  threads = thread_queries.map do |queries|
    Thread.new { perform_searches(index, queries) }
  end
  threads.each(&:join)
end
puts "   Time: #{frozen_time.round(3)}s"
puts "   Queries/sec: #{(NUM_QUERIES / frozen_time).round(2)}"
puts "   Speedup vs single-threaded: #{(single_time / frozen_time).round(2)}x"
puts "   Speedup vs unfrozen multi-threaded: #{(unfrozen_time / frozen_time).round(2)}x"

puts "\n" + "=" * 50
puts "Summary:"
puts "  Freezing the index improved multi-threaded performance by #{((unfrozen_time / frozen_time - 1) * 100).round(1)}%"
puts "  Theoretical max speedup with #{NUM_THREADS} threads: #{NUM_THREADS}x"
puts "  Actual speedup achieved: #{(single_time / frozen_time).round(2)}x (#{((single_time / frozen_time) / NUM_THREADS * 100).round(1)}% efficiency)"

# Additional test: Verify frozen index is read-only
puts "\n" + "=" * 50
puts "Verification: Frozen index is read-only"
begin
  index.add(Numo::SFloat.new(1, DIMENSIONS).rand)
  puts "  ERROR: Frozen index allowed modification!"
rescue => e
  puts "  ✓ Frozen index correctly prevents modification"
  puts "    Error: #{e.message}"
end