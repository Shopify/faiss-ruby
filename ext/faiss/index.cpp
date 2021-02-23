#include <faiss/Index.h>
#include <faiss/IndexFlat.h>
#include <faiss/IndexHNSW.h>
#include <faiss/IndexIVFFlat.h>
#include <faiss/IndexLSH.h>
#include <faiss/IndexScalarQuantizer.h>
#include <faiss/IndexPQ.h>
#include <faiss/IndexIVFPQ.h>
#include <faiss/IndexIVFPQR.h>
#include <faiss/index_io.h>

#include <rice/Array.hpp>
#include <rice/Constructor.hpp>
#include <rice/Module.hpp>

#include "utils.h"

void init_index(Rice::Module& m) {
  Rice::define_class_under<faiss::Index>(m, "Index")
    .define_method(
      "d",
      *[](faiss::Index &self) {
        return self.d;
      })
    .define_method(
      "trained?",
      *[](faiss::Index &self) {
        return self.is_trained;
      })
    .define_method(
      "ntotal",
      *[](faiss::Index &self) {
        return self.ntotal;
      })
    .define_method(
      "_train",
      *[](faiss::Index &self, int64_t n, Rice::Object o) {
        const float *x = float_array(o);
        self.train(n, x);
      })
    .define_method(
      "_add",
      *[](faiss::Index &self, int64_t n, Rice::Object o) {
        const float *x = float_array(o);
        self.add(n, x);
      })
    .define_method(
      "_search",
      *[](faiss::Index &self, int64_t n, Rice::Object o, int64_t k) {
        const float *x = float_array(o);
        float *distances = new float[k * n];
        int64_t *labels = new int64_t[k * n];

        self.search(n, x, k, distances, labels);

        auto dstr = result(distances, k * n);
        auto lstr = result(labels, k * n);

        Rice::Array ret;
        ret.push(dstr);
        ret.push(lstr);
        return ret;
      })
    .define_method(
      "save",
      *[](faiss::Index &self, const char *fname) {
        faiss::write_index(&self, fname);
      })
    .define_singleton_method(
      "load",
      *[](const char *fname) {
        return faiss::read_index(fname);
      });

  Rice::define_class_under<faiss::IndexFlatL2, faiss::Index>(m, "IndexFlatL2")
    .define_constructor(Rice::Constructor<faiss::IndexFlatL2, int64_t>());

  Rice::define_class_under<faiss::IndexFlatIP, faiss::Index>(m, "IndexFlatIP")
    .define_constructor(Rice::Constructor<faiss::IndexFlatIP, int64_t>());

  Rice::define_class_under<faiss::IndexHNSWFlat, faiss::Index>(m, "IndexHNSWFlat")
    .define_constructor(Rice::Constructor<faiss::IndexHNSWFlat, int, int>());

  Rice::define_class_under<faiss::IndexIVFFlat, faiss::Index>(m, "IndexIVFFlat")
    .define_constructor(Rice::Constructor<faiss::IndexIVFFlat, faiss::Index*, size_t, size_t>());

  Rice::define_class_under<faiss::IndexLSH, faiss::Index>(m, "IndexLSH")
    .define_constructor(Rice::Constructor<faiss::IndexLSH, int64_t, int>());

  Rice::define_class_under<faiss::IndexScalarQuantizer, faiss::Index>(m, "IndexScalarQuantizer")
    .define_constructor(Rice::Constructor<faiss::IndexScalarQuantizer, int, faiss::ScalarQuantizer::QuantizerType>());

  Rice::define_class_under<faiss::IndexPQ, faiss::Index>(m, "IndexPQ")
    .define_constructor(Rice::Constructor<faiss::IndexPQ, int, size_t, size_t>());

  Rice::define_class_under<faiss::IndexIVFScalarQuantizer, faiss::Index>(m, "IndexIVFScalarQuantizer")
    .define_constructor(Rice::Constructor<faiss::IndexIVFScalarQuantizer, faiss::Index*, size_t, size_t, faiss::ScalarQuantizer::QuantizerType>());

  Rice::define_class_under<faiss::IndexIVFPQ, faiss::Index>(m, "IndexIVFPQ")
    .define_constructor(Rice::Constructor<faiss::IndexIVFPQ, faiss::Index*, size_t, size_t, size_t, size_t>());

  Rice::define_class_under<faiss::IndexIVFPQR, faiss::Index>(m, "IndexIVFPQR")
    .define_constructor(Rice::Constructor<faiss::IndexIVFPQR, faiss::Index*, size_t, size_t, size_t, size_t, size_t, size_t>());
}
