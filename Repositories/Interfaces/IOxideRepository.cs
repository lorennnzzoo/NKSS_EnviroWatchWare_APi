using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IOxideRepository
    {
        Oxide GetById(int id);
        IEnumerable<Oxide> GetAll();
        void Add(Post.Oxide oxide);
        void Update(Oxide oxide);
        void Delete(int id);
    }
}
