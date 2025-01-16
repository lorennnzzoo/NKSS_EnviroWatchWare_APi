using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Repositories.Interfaces
{
    public interface IStationRepository
    {
        Station GetById(int id);
        IEnumerable<Station> GetAll();        
        void Add(Post.Station station);
        void Update(Station station);
        void Delete(int id);
        IEnumerable<int> GetActiveStationIds();
       
    }
}
