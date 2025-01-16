using Models;
using Post = Models.Post;
using Services;
using System;
using System.Web.Http;
using System.Net.Http;
using System.Net;

namespace NKSS_EnviroWatchWare_APi.Controllers.WatchWare
{
    [Authorize]
    [RoutePrefix("ScalingFactor")]
    public class ScalingFactorController : ApiController
    {
        private readonly ScalingFactorService scaling_factor_service;
        private Helpers.Validator validator = new Helpers.Validator();
        public ScalingFactorController(ScalingFactorService _scaling_factor_service)
        {
            this.scaling_factor_service = _scaling_factor_service;
        }

        [HttpGet]
        [Route("GetScalingFactor")]
        public IHttpActionResult Get(int id)
        {
            try
            {
                var scalingFactor = scaling_factor_service.GetScalingFactorById(id);
                if (scalingFactor == null)
                    return NotFound();
                return Ok(scalingFactor);
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
        [Route("GetAllScalingFactors")]
        public IHttpActionResult GetAll()
        {
            try
            {
                var scalingFactors = scaling_factor_service.GetAllScalingFactors();
                return Ok(scalingFactors);
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
        [Route("AddScalingFactor")]
        public IHttpActionResult Add(Post.ScalingFactor scalingFactor)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(scalingFactor);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                scaling_factor_service.CreateScalingFactor(scalingFactor);
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
        [Route("UpdateScalingFactor")]
        public IHttpActionResult Update(ScalingFactor scalingFactor)
        {
            try
            {
                //if (oxide == null)
                //    return BadRequest("Invalid data.");
                var result = validator.ValidateProperties(scalingFactor);
                if (!result.isValid)
                {
                    return BadRequest(result.errorMessage);
                }

                scaling_factor_service.UpdateScalingFactor(scalingFactor);
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
        [Route("DeleteScalingFactor")]
        public IHttpActionResult Delete(int id)
        {
            try
            {
                scaling_factor_service.DeleteScalingFactor(id);
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
    }
}
