using Models;
using Post = Models.Post;
using Repositories.Interfaces;
using Services.Interfaces;
using System.Collections.Generic;
using System.Linq;

namespace Services
{
    public class ChannelService : IChannelService
    {
        private readonly IChannelRepository _channelRepository;
        public ChannelService(IChannelRepository channelRepository)
        {
            _channelRepository = channelRepository;
        }
        public void CreateChannel(Post.Channel channel)
        {
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
            _channelRepository.Update(channel);
        }
    }
}
