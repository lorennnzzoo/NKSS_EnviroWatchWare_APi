using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IAnalyzerService
    {
        IEnumerable<Analyzer> GetAllAnalyzers();
        Analyzer GetAnalyzerById(int id);
        void CreateAnalyzer(Post.Analyzer analyzer);
        void UpdateAnalyzer(Analyzer analyzer);
        void DeleteAnalyzer(int id);
    }
}
