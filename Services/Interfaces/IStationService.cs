using Models;
using Post = Models.Post;
using System.Collections.Generic;

namespace Services.Interfaces
{
    public interface IStationService
    {
        IEnumerable<Station> GetAllStations();
        IEnumerable<Station> GetAllStationsByCompanyId(int companyId);
        Station GetStationById(int id);
        void CreateStation(Post.Station station);
        void UpdateStation(Station station);
        void DeleteStation(int id);
    }
}
