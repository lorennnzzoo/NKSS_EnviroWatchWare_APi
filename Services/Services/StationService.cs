using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class StationService : IStationService
    {
        private readonly IStationRepository _stationRepository;
        public StationService(IStationRepository stationRepository)
        {
            _stationRepository = stationRepository;

        }
        public void CreateStation(Post.Station station)
        {
            _stationRepository.Add(station);
        }

        public void DeleteStation(int id)
        {
            _stationRepository.Delete(id);
        }

        public IEnumerable<Station> GetAllStations()
        {
            return _stationRepository.GetAll();
        }

        public IEnumerable<Station> GetAllStationsByCompanyId(int companyId)
        {
            return _stationRepository.GetAll().Where(e => e.CompanyId == companyId);
        }

        public Station GetStationById(int id)
        {
            return _stationRepository.GetById(id);
        }

        public void UpdateStation(Station station)
        {
            _stationRepository.Update(station);
        }
    }
}
