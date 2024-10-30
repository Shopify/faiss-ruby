require_relative "test_helper"

class ThreadBenchmark < Minitest::Test
  def test_benchmark_index_flat_ip
    Numo::NArray.srand(1234) # set the random seed

    d = 3072 # dimensions
    nb = 2 * 100000 # number of vectors in the database
    nq = 1 # number of queries
    xb = Numo::SFloat.new(nb, d).rand # database vectors
    xb[true, 0] += Numo::Int64.new(nb).seq / 1000.0 # add a sequence to the first dimension
    xq = Numo::SFloat.new(nq, d).rand # query vectors
    xq[true, 0] += Numo::Int64.new(nq).seq / 1000.0 # add a sequence to the first dimension

    index = Faiss::IndexFlatIP.new(d) # create an index

    index.add(xb) # add the database vectors to the index

    k = 4 # number of nearest neighbors to search for
    reps = 100 # number of repetitions
    pool_size = 2 # number of threads

    puts "#{reps} repetitions"

    puts "Running single-threaded search..."

    time = measure {
      reps.times do
        index.search(xq, k) # search for the nearest neighbors
      end
    }

    puts "Time taken: #{time} seconds"

    queue = Thread::Queue.new
    pool = pool_size.times.map {
      Thread.new {
        wake_count = 0

        loop {
          args = queue.pop
          break if args == :end
          wake_count += 1
          index.search(xq, k)
        }

        wake_count
      }
    }

    wake_counts = nil

    puts "Running multi-threaded search with #{pool_size} threads..."

    time = measure {
      reps.times do
        queue << nil
      end

      # Release the threads
      pool.each { queue << :end }

      # Collect the wake counts
      wake_counts = pool.map(&:value)
    }

    puts "Time taken with threads: #{time} seconds"
    puts "Wake counts: #{wake_counts.inspect}"
  end

  private

  def measure
    x = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - x
  end
end
