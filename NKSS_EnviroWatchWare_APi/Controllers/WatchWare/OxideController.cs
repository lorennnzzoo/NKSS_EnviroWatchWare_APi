using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize(Roles = "Admin")]
    [RoutePrefix("Oxide")]
    public class OxideController : ApiController
    {
        private readonly OxideService oxide_service;
        private readonly Helpers.Validator validator = new Helpers.Validator();
        public OxideController(OxideService _oxide_service)
        {
            this.oxide_service = _oxide_service;
        }

        [HttpGet]
        [Route("GetOxide")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var oxide = oxide_service.GetOxideById(id);
                if (oxide == null)
                    return NotFound();
                return Ok(oxide);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpGet]
        [Route("GetAllOxides")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var oxides = oxide_service.GetAllOxides();
                return Ok(oxides);
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPost]
        [Route("AddOxide")]
        public IHttpActionResult Add(Post.Oxide oxide)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(oxide);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                oxide_service.CreateOxide(oxide);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpPut]
        [Route("UpdateOxide")]
        public IHttpActionResult Update(Oxide oxide)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var (isValid, errorMessage) = validator.ValidateProperties(oxide);
                if (!isValid)
                {
                    return BadRequest(errorMessage);
                }

                oxide_service.UpdateOxide(oxide);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.ToString())
                };

                return ResponseMessage(response);
            }
        }

        [HttpDelete]
        [Route("DeleteOxide")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                oxide_service.DeleteOxide(id);
                return Ok();
            }
            catch (Exception ex)
            {
                var response = new HttpResponseMessage(HttpStatusCode.InternalServerError)
                {
                    Content = new StringContent(ex.Message)
                };

                return ResponseMessage(response);
            }
        }
    }
}
