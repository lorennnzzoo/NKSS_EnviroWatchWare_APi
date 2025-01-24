using Models;
using Post= Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class AnalyzerService : IAnalyzerService
    {
        private readonly IAnalyzerRepository _analyzerRepository;
        private readonly IChannelRepository _channelRepository;
        public AnalyzerService(IAnalyzerRepository analyzerRepository, IChannelRepository channelRepository)
        {
            _analyzerRepository = analyzerRepository;
            _channelRepository = channelRepository;
        }
        public void CreateAnalyzer(Post.Analyzer analyzer)
        {
            _analyzerRepository.Add(analyzer);
        }

        public void DeleteAnalyzer(int id)
        {
            var channelsLinkedToAnalyzer = _channelRepository.GetAll().Where(e => e.ProtocolId == id).ToList();
            if (channelsLinkedToAnalyzer.Any())
            {
                var analyzer = _analyzerRepository.GetById(id);
                throw new Exceptions.AnalyzerCannotBeDeletedException(analyzer.ProtocolType, string.Join(",", channelsLinkedToAnalyzer.Select(e => e.Name)));
            }
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
