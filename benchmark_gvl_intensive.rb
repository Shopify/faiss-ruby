#!/usr/bin/env ruby

require "bundler/setup"
require "faiss"
require "benchmark"
require "numo/narray"

# Parameters for more intensive testing
DIMENSIONS = 256
NUM_VECTORS = 50_000
NUM_QUERIES = 100
NUM_THREADS = [1, 2, 4, 8]
K_NEIGHBORS = 100
ITERATIONS = 10

puts "GVL Release Intensive Benchmark for Faiss Index"
puts "=" * 50
puts "Configuration:"
puts "  Dimensions: #{DIMENSIONS}"
puts "  Index vectors: #{NUM_VECTORS}"
puts "  Queries per iteration: #{NUM_QUERIES}"
puts "  Iterations: #{ITERATIONS}"
puts "  K neighbors: #{K_NEIGHBORS}"
puts "  Thread counts to test: #{NUM_THREADS.inspect}"
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

# Helper method to perform intensive searches
def perform_intensive_search(index, queries, k)
  results = []
  queries.shape[0].times do |i|
    query = queries[i, true].reshape(1, queries.shape[1])
    distances, indices = index.search(query, k)
    # Simulate some processing
    results << [distances.mean, indices.max]
  end
  results
end

# Results storage
results = {
  unfrozen: {},
  frozen: {}
}

puts "Running benchmarks..."
puts "-" * 50

NUM_THREADS.each do |num_threads|
  puts "\nTesting with #{num_threads} thread(s):"
  
  # Test with unfrozen index
  gc_was_disabled = GC.disable
  print "  Unfrozen index: "
  unfrozen_time = Benchmark.realtime do
    if num_threads == 1
      ITERATIONS.times do
        perform_intensive_search(index, query_data, K_NEIGHBORS)
      end
    else
      queries_per_thread = query_data.shape[0] / num_threads
      thread_queries = num_threads.times.map do |i|
        start_idx = i * queries_per_thread
        end_idx = (i + 1) * queries_per_thread
        query_data[start_idx...end_idx, true]
      end
      
      ITERATIONS.times do
        threads = thread_queries.map do |queries|
          Thread.new { perform_intensive_search(index, queries, K_NEIGHBORS) }
        end
        threads.each(&:join)
      end
    end
  end
  GC.enable unless gc_was_disabled
  
  queries_per_sec = (NUM_QUERIES * ITERATIONS / unfrozen_time).round(2)
  results[:unfrozen][num_threads] = { time: unfrozen_time, qps: queries_per_sec }
  puts "#{unfrozen_time.round(3)}s (#{queries_per_sec} queries/sec)"
  
  # Test with frozen index
  index.freeze if num_threads > 1 && !index.frozen?
  
  gc_was_disabled = GC.disable
  print "  Frozen index:   "
  frozen_time = Benchmark.realtime do
    if num_threads == 1
      ITERATIONS.times do
        perform_intensive_search(index, query_data, K_NEIGHBORS)
      end
    else
      queries_per_thread = query_data.shape[0] / num_threads
      thread_queries = num_threads.times.map do |i|
        start_idx = i * queries_per_thread
        end_idx = (i + 1) * queries_per_thread
        query_data[start_idx...end_idx, true]
      end
      
      ITERATIONS.times do
        threads = thread_queries.map do |queries|
          Thread.new { perform_intensive_search(index, queries, K_NEIGHBORS) }
        end
        threads.each(&:join)
      end
    end
  end
  GC.enable unless gc_was_disabled
  
  queries_per_sec = (NUM_QUERIES * ITERATIONS / frozen_time).round(2)
  results[:frozen][num_threads] = { time: frozen_time, qps: queries_per_sec }
  puts "#{frozen_time.round(3)}s (#{queries_per_sec} queries/sec)"
  
  if num_threads > 1
    speedup = (unfrozen_time / frozen_time).round(2)
    improvement = ((unfrozen_time / frozen_time - 1) * 100).round(1)
    puts "  → Freezing improved performance by #{improvement}% (#{speedup}x speedup)"
  end
  
  # Unfreeze for next iteration
  index = Faiss::IndexFlatL2.new(DIMENSIONS) if index.frozen?
  index.add(train_data) if index.ntotal == 0
end

puts "\n" + "=" * 50
puts "Performance Summary:"
puts "-" * 50
puts "Thread Count | Unfrozen QPS | Frozen QPS | Improvement"
puts "-" * 50

baseline_qps = results[:unfrozen][1][:qps]

NUM_THREADS.each do |n|
  unfrozen_qps = results[:unfrozen][n][:qps]
  frozen_qps = results[:frozen][n][:qps]
  improvement = n > 1 ? ((frozen_qps / unfrozen_qps - 1) * 100).round(1) : 0
  
  unfrozen_scaling = (unfrozen_qps / baseline_qps).round(2)
  frozen_scaling = (frozen_qps / baseline_qps).round(2)
  
  puts "#{n.to_s.rjust(12)} | #{unfrozen_qps.to_s.rjust(12)} | #{frozen_qps.to_s.rjust(10)} | #{improvement > 0 ? '+' : ''}#{improvement}%"
  puts "             | (#{unfrozen_scaling}x scaling) | (#{frozen_scaling}x scaling) |" if n > 1
end

puts "\n" + "=" * 50
puts "Key Findings:"
puts "  • Single-threaded baseline: #{baseline_qps} queries/sec"

best_unfrozen = NUM_THREADS[1..-1].map { |n| results[:unfrozen][n][:qps] }.max
best_frozen = NUM_THREADS[1..-1].map { |n| results[:frozen][n][:qps] }.max
overall_improvement = ((best_frozen / best_unfrozen - 1) * 100).round(1)

puts "  • Best multi-threaded (unfrozen): #{best_unfrozen} queries/sec"
puts "  • Best multi-threaded (frozen): #{best_frozen} queries/sec"
puts "  • Overall improvement from freezing: #{overall_improvement}%"

max_scaling = (best_frozen / baseline_qps).round(2)
efficiency = (max_scaling / NUM_THREADS.max * 100).round(1)
puts "  • Maximum scaling achieved: #{max_scaling}x (#{efficiency}% parallel efficiency)"