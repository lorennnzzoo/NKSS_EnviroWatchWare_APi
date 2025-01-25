using Models;
using DashBoard = Models.DashBoard;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;
using Models.DashBoard;
using System;

namespace Services
{
    public class ChannelDataFeedService : IChannelDataFeedService
    {
        private readonly IChannelDataFeedRepository _channelDataFeedRepository;
        private readonly IStationRepository _stationRepository;
        public ChannelDataFeedService(IChannelDataFeedRepository channelDataFeedRepository, IStationRepository stationRepository)
        {
            _channelDataFeedRepository = channelDataFeedRepository;
            _stationRepository = stationRepository;
        }
        public List<ChannelDataFeedByStation> GetAllStationsFeed()
        {
            List<DashBoard.ChannelDataFeedByStation> allStationsFeed=new List<ChannelDataFeedByStation>();
            IEnumerable<int> stationIds = _stationRepository.GetActiveStationIds();
            foreach(int id in stationIds)
            {
                IEnumerable<DashBoard.ChannelDataFeed> stationFeedbyId = _channelDataFeedRepository.GetByStationId(id);
                DashBoard.ChannelDataFeedByStation stationfeed = new ChannelDataFeedByStation
                {
                    Station = new DashBoard.Station
                    {
                        DataFeed = stationFeedbyId.Select(e=>new ChannelData
                        {
                            ChannelName=e.ChannelName,
                            ChannelValue=e.ChannelValue,
                            Units=e.Units,
                            ChannelDataLogTime= e.ChannelDataLogTime,
                            PcbLimit=e.PcbLimit
                        }).ToList()
                    }
                };
                allStationsFeed.Add(stationfeed);
            }
            return allStationsFeed;
        }

        public List<ChannelDataFeed> GetStationFeed(int stationId)
        {
            List<DashBoard.ChannelDataFeed> stationFeed = new List<ChannelDataFeed>();
            stationFeed = _channelDataFeedRepository.GetByStationId(stationId).ToList();            
            return stationFeed;
        }

        public List<Models.Station> GetStationNames()
        {
            return _stationRepository.GetAll().ToList();
        }

        public void InsertChannelData(int channelId, decimal channelValue, DateTime datetime, string passPhrase)
        {
            if (channelValue < 0)
            {
                channelValue = 0;
            }
            _channelDataFeedRepository.InsertChannelData(channelId, channelValue, datetime, passPhrase);
        }
    }
}
