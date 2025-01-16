using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IAnalyzerRepository
    {
        Analyzer GetById(int id);
        IEnumerable<Analyzer> GetAll();
        void Add(Post.Analyzer analyzer);
        void Update(Analyzer analyzer);
        void Delete(int id);
    }
}
