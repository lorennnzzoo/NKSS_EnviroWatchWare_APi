using Models;
using Post= Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;

namespace Services
{
    public class AnalyzerService : IAnalyzerService
    {
        private readonly IAnalyzerRepository _analyzerRepository;
        public AnalyzerService(IAnalyzerRepository analyzerRepository)
        {
            _analyzerRepository = analyzerRepository;
        }
        public void CreateAnalyzer(Post.Analyzer analyzer)
        {
            _analyzerRepository.Add(analyzer);
        }

        public void DeleteAnalyzer(int id)
        {
            _analyzerRepository.Delete(id);
        }

        public IEnumerable<Analyzer> GetAllAnalyzers()
        {
            return _analyzerRepository.GetAll();
        }

        public Analyzer GetAnalyzerById(int id)
        {
            return _analyzerRepository.GetById(id);
        }

        public void UpdateAnalyzer(Analyzer analyzer)
        {
            _analyzerRepository.Update(analyzer);
        }
    }
}
