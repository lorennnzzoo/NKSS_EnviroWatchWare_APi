using Models;
using Post = Models.Post;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Services.Interfaces
{
    public interface IChannelService
    {
        IEnumerable<Channel> GetAllChannels();
        IEnumerable<Channel> GetAllChannelsByStationId(int stationId);

        IEnumerable<Channel> GetAllChannelsByProtocolId(int protocolId);
        Channel GetChannelById(int id);
        void CreateChannel(Post.Channel channel);
        void UpdateChannel(Channel channel);
        void DeleteChannel(int id);
    }
}
