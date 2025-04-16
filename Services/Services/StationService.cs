using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;
using System;

namespace Services
{
    public class StationService : IStationService
    {
        private readonly IStationRepository _stationRepository;
        private readonly IChannelService channelService;
        public StationService(IStationRepository stationRepository, IChannelService _channelService)
        {
            _stationRepository = stationRepository;
            channelService = _channelService;
        }
        public void CreateStation(Post.Station station)
        {
            var allStationsOfCompany = _stationRepository.GetAll().Where(e => e.CompanyId == station.CompanyId).Where(e => e.Name.ToUpper() == station.Name.ToUpper());
            if (allStationsOfCompany.Any())
            {
                throw new Exceptions.StationWithSameNameExists(station.Name);
            }
            _stationRepository.Add(station);
        }

        public void DeleteStation(int id)
        {
            var channelsLinkedToStation = channelService.GetAllChannelsByStationId(id).ToList();
            if (channelsLinkedToStation.Any())
            {
                foreach(var channel in channelsLinkedToStation)
                {
                    channelService.DeleteChannel(Convert.ToInt32( channel.Id));
                }
            }
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

        public void UpdateStation(Models.Put.Station station)
        {
            var allStationsOfCompany = _stationRepository.GetAll().Where(e=>e.Id!=station.Id).Where(e => e.CompanyId == station.CompanyId).Where(e => e.Name.ToUpper() == station.Name.ToUpper());
            if (allStationsOfCompany.Any())
            {
                throw new Exceptions.StationWithSameNameExists(station.Name);
            }
            _stationRepository.Update(station);
        }
    }
}
