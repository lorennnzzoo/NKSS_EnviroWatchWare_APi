using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IOxideService
    {
        IEnumerable<Oxide> GetAllOxides();
        Oxide GetOxideById(int id);
        void CreateOxide(Post.Oxide oxide);
        void UpdateOxide(Oxide oxide);
        void DeleteOxide(int id);
    }
}
