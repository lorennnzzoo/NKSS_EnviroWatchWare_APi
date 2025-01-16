using Models;
using DashBoard = Models.DashBoard;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;
using Models.DashBoard;

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
                        Name = stationFeedbyId.Select(e => e.Name).FirstOrDefault(),
                        DataFeed = stationFeedbyId.Select(e=>new ChannelData
                        {
                            ChannelName=e.ChannelName,
                            ChannelValue=e.ChannelValue,
                            Units=e.Units,
                            ChannelDataLogTime= e.ChannelDataLogTime,
                            PcbLimit=e.PcbLimit,
                            Minimum=e.Minimum,
                            Maximum=e.Maximum,
                            Average=e.Average
                        }).ToList()
                    }
                };
                allStationsFeed.Add(stationfeed);
            }
            return allStationsFeed;
        }
    }
}
