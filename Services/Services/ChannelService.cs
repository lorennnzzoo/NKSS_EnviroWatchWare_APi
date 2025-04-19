using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;
using System;

namespace Services
{
    public class ChannelService : IChannelService
    {
        private readonly IChannelRepository _channelRepository;
        private readonly IStationRepository stationRepository;
        public ChannelService(IChannelRepository channelRepository, IStationRepository _stationRepository)
        {
            _channelRepository = channelRepository;
            stationRepository = _stationRepository;
        }
        public void CreateChannel(Post.Channel channel)
        {
            //checking if channel with same name exists in the same station
            var station = stationRepository.GetById(Convert.ToInt32( channel.StationId));
            var allChannelsOfStation = _channelRepository.GetAll().Where(e => e.StationId == channel.StationId).Where(e => e.Name.ToUpper() == channel.Name.ToUpper());
            if (allChannelsOfStation.Any())
            {
                throw new Exceptions.ChannelWithSameNameExists(channel.Name,station.Name);
            }

            //checking if channel has isCpcb isSpcb flags true even though station doesnt
            

            if (channel.IsCpcb && !station.IsCpcb)
            {
                throw new Exception("Channel is marked as CPCB but the associated Station is not marked as CPCB.");
            }

            if (channel.IsSpcb && !station.IsSpcb)
            {
                throw new Exception("Channel is marked as SPCB but the associated Station is not marked as SPCB.");
            }

            _channelRepository.Add(channel);
        }

        public void DeleteChannel(int id)
        {
            _channelRepository.Delete(id);
        }

        public IEnumerable<Channel> GetAllChannels()
        {
            return _channelRepository.GetAll();
        }

        public IEnumerable<Channel> GetAllChannelsByProtocolId(int protocolId)
        {
            return _channelRepository.GetAll().Where(e => e.ProtocolId == protocolId);
        }

        public IEnumerable<Channel> GetAllChannelsByStationId(int stationId)
        {
            return _channelRepository.GetAll().Where(e => e.StationId == stationId);
        }

        public Channel GetChannelById(int id)
        {
            return _channelRepository.GetById(id);
        }

        public void UpdateChannel(Channel channel)
        {
            var station = stationRepository.GetById(Convert.ToInt32(channel.StationId));
            var allChannelsOfStation = _channelRepository.GetAll().Where(e => e.StationId == channel.StationId).Where(e => e.Name.ToUpper() == channel.Name.ToUpper()).Where(e=>e.Id!=channel.Id);
            if (allChannelsOfStation.Any())
            {
                throw new Exceptions.ChannelWithSameNameExists(channel.Name, station.Name);
            }
            if (channel.IsCpcb && !station.IsCpcb)
            {
                throw new Exception("Channel is marked as CPCB but the associated Station is not marked as CPCB.");
            }

            if (channel.IsSpcb && !station.IsSpcb)
            {
                throw new Exception("Channel is marked as SPCB but the associated Station is not marked as SPCB.");
            }
            _channelRepository.Update(channel);
        }
    }
}
