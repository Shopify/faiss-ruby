require_relative "test_helper"

class ThreadBenchmark < Minitest::Test
  def test_benchmark_index_flat_ip
    Numo::NArray.srand(1234) # set the random seed

    d = 3072 # dimensions
    nb = 100000 # number of vectors in the database
    nq = 10 # number of queries
    xb = Numo::SFloat.new(nb, d).rand # database vectors
    xb[true, 0] += Numo::Int64.new(nb).seq / 1000.0 # add a sequence to the first dimension
    xq = Numo::SFloat.new(nq, d).rand # query vectors
    xq[true, 0] += Numo::Int64.new(nq).seq / 1000.0 # add a sequence to the first dimension

    index = Faiss::IndexFlatIP.new(d) # create an index

    index.add(xb) # add the database vectors to the index

    k = 4 # number of nearest neighbors to search for

    time = measure {
      50.times do
        index.search(xq, k) # search for the nearest neighbors
      end
    }

    puts "Time taken: #{time} seconds"

    queue = Thread::Queue.new
    pool = 50.times.map { Thread.new { queue.pop; index.search(xq, k) } }

    time = measure {
      pool.each do
        queue << nil
      end.each(&:join)
    }

    puts "Time taken with threads: #{time} seconds"
  end

  private

  def measure
    x = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    yield
    Process.clock_gettime(Process::CLOCK_MONOTONIC) - x
  end
end
